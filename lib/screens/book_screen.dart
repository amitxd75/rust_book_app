import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/bookmarks_service.dart';
import '../services/offline_cache_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/circles.dart';
import '../widgets/gemini_chat_sheet.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/bookmark.dart';
import '../widgets/bookmarks_sheet.dart';
import '../widgets/study_dashboard.dart';

/// The primary screen containing the WebView to display the Rust Book,
/// offering navigation, bookmarking, offline caching, and Gemini chat assistant.
class BookScreen extends StatefulWidget {
  /// Creates the [BookScreen] widget.
  const BookScreen({super.key});

  @override
  State<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends State<BookScreen> with WidgetsBindingObserver {
  static const _homeUrl = 'https://rust-book.cs.brown.edu/';

  late final WebViewController _controller;
  final _bookmarksService = BookmarksService();
  final _offlineCacheService = OfflineCacheService();

  double _progress = 0;
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _bookmarked = false;
  String _currentUrl = _homeUrl;
  String _currentTitle = 'The Rust Programming Language';

  // Dashboard state and metrics tracking
  bool _showDashboard = true;
  DateTime? _readerEntryTime;
  int _readingTimeSeconds = 0;
  List<String> _readChapters = [];
  String _lastVisitedUrl = _homeUrl;
  final _searchController = TextEditingController();

  // Pre-cached dependencies for bottom sheets to avoid frame drops on launch
  List<Bookmark> _cachedBookmarks = [];
  String? _cachedApiKey;
  String _cachedSelectedModel = 'gemini-3.1-flash-lite';
  List<Map<String, dynamic>> _cachedChatHistory = [];
  String _cachedSkillPrompt = '';

  List<Map<String, String>> _chapters = [
    {
      'title': 'Introduction',
      'url': 'https://rust-book.cs.brown.edu/ch00-00-introduction.html'
    },
  ];

  bool get _isTesting => Platform.environment.containsKey('FLUTTER_TEST');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadReadingMetrics();
    if (!_isTesting) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (p) => setState(() => _progress = p / 100),
            onPageStarted: (url) {
              _bookmarksService.saveLastVisitedUrl(url);
              _bookmarksService.markChapterAsRead(url);
              _loadReadingMetrics();
            },
            onNavigationRequest: (request) {
              // Intercept inside-WebView links to route them through our offline caching handler!
              if (request.url.startsWith('https://rust-book.cs.brown.edu') ||
                  request.url.startsWith('http://rust-book.cs.brown.edu')) {
                _loadPage(request.url);
                return NavigationDecision
                    .prevent; // Prevent default WebView loading
              }
              return NavigationDecision.navigate;
            },
            onPageFinished: (url) async {
              // Inject custom stylesheets to make mdBook transparent without altering original fonts/colors/styles
              await _controller.runJavaScript('''
                (function() {
                  var style = document.getElementById('glass-theme-overrides');
                  if (!style) {
                    style = document.createElement('style');
                    style.id = 'glass-theme-overrides';
                    style.innerHTML = `
                      /* Force the sidebar theme variable to solid dark to ensure menu item readability */
                      :root {
                        --sidebar-bg: rgba(18, 20, 24, 0.98) !important;
                      }

                      /* Transparent backgrounds on the root theme containers */
                      .theme-light, .theme-coal, .theme-navy, .theme-dark, .theme-rust {
                        background: transparent !important;
                        background-color: transparent !important;
                      }

                      /* Transparent backgrounds on all nested page wrapper layouts to let drifting orbits show through */
                      html, body, .page, #content, .page-wrapper, #page-wrapper, main,
                      .theme-light, .theme-coal, .theme-navy, .theme-dark, .theme-rust {
                        background: transparent !important;
                        background-color: transparent !important;
                        -webkit-overflow-scrolling: touch !important;
                        overscroll-behavior-y: contain !important;
                      }

                      /* Transparent menu bar/toolbar wrappers at the top (remove website navbar wallpapers) */
                      .menu-bar, .menu-bar-outer, #menu-bar, .menu-bar-sticky, .nav-chapters, .mobile-nav-chapters {
                        background: transparent !important;
                        background-color: transparent !important;
                        box-shadow: none !important;
                      }

                      /* Table of contents / sidebar adjustments */
                      #sidebar {
                        position: fixed !important;
                        top: 0 !important;
                        left: 0 !important;
                        height: 100% !important;
                        z-index: 10000 !important;
                        background: rgba(18, 20, 24, 0.98) !important;
                        border-right: 1px solid rgba(255, 255, 255, 0.08) !important;
                        box-shadow: 8px 0 30px rgba(0,0,0,0.6) !important;
                        transition: transform 0.28s cubic-bezier(0.16, 1, 0.3, 1) !important;
                        will-change: transform; /* Promotes sidebar to hardware GPU compositor layer to eliminate slide-out animation lag */
                      }

                      /* Layout fix to prevent sidebar from pushing main content to the right */
                      .sidebar-visible #page-wrapper {
                        margin-left: 0 !important;
                        transform: none !important;
                      }

                       /* Better spacing for reading on mobile, with custom bottom padding so page content scrolls behind the floating bottom bar */
                       #content main {
                         padding: 24px 24px 40px 24px !important;
                         max-width: 800px !important;
                         margin: 0 auto !important;
                       }

                       /* Pushes all end-of-page content (like quizzes, buttons, and navigation) up past the floating bottom bar */
                       #page-wrapper, .page-wrapper, .quiz-wrapper {
                         padding-bottom: 140px !important;
                       }

                      ::-webkit-scrollbar {
                        width: 6px;
                      }
                      ::-webkit-scrollbar-thumb {
                        background: rgba(222, 123, 63, 0.35);
                        border-radius: 3px;
                      }

                      /* Hide GitHub repository, Print/PDF, and native website bookmark buttons from the mdBook top header bar */
                      .git-repository-button,
                      .print-button,
                      .bookmark-button,
                      #bookmark-button,
                      a[title*="Print"],
                      a[aria-label*="Print"],
                      a[title*="Git"],
                      a[aria-label*="Git"],
                      a[title*="Bookmark"],
                      a[aria-label*="Bookmark"],
                      a[href*="github.com"],
                      a[href*="print.html"] {
                        display: none !important;
                      }
                    `;
                    document.head.appendChild(style);
                  }

                  // Migrated away from navy (blue) theme to coal (charcoal dark) theme to remove the bluescreen
                  if (localStorage.getItem('mdbook-theme') === 'navy' || !localStorage.getItem('mdbook-theme')) {
                    localStorage.setItem('mdbook-theme', 'coal');
                    document.documentElement.className = 'theme-coal';
                  }

                  // MutationObserver to capture and hide the selection annotation pencil icon tooltip dynamically
                  var observer = new MutationObserver(function(mutations) {
                    mutations.forEach(function(mutation) {
                      mutation.addedNodes.forEach(function(node) {
                        if (node.nodeType === 1) {
                          var className = node.getAttribute ? (node.getAttribute('class') || '') : '';
                          var id = node.getAttribute ? (node.getAttribute('id') || '') : '';
                          var text = node.textContent || '';

                          if (text.trim() === '✏️' ||
                              text.trim() === '✏' ||
                              className.includes('annotation') ||
                              className.includes('highlight') ||
                              id.includes('annotation') ||
                              id.includes('highlight')) {
                            node.style.display = 'none';
                            node.style.visibility = 'hidden';
                            node.style.opacity = '0';
                            node.style.pointerEvents = 'none';
                          }
                        }
                      });
                    });
                  });
                  observer.observe(document.body, { childList: true, subtree: true });
                })()
              ''');

              final title = await _controller.getTitle();
              final marked = await _bookmarksService.isBookmarked(url);
              if (!mounted) return;
              setState(() {
                _currentUrl = url;
                _currentTitle = title?.isNotEmpty == true ? title! : url;
                _bookmarked = marked;
                _progress = 1;
              });

              // Autosave to offline cache if online and the page is loaded successfully
              final isOnline =
                  await _offlineCacheService.hasInternetConnection();
              if (isOnline && !url.contains('data:text/html')) {
                try {
                  final htmlObj =
                      await _controller.runJavaScriptReturningResult(
                          "document.documentElement.outerHTML");
                  final html = _decodeWebViewResult(htmlObj);
                  if (html.isNotEmpty && !html.contains("Offline Mode")) {
                    await _offlineCacheService.savePage(url, html);
                  }
                } catch (_) {}
              }

              // Scrape live table of contents dynamically from the page's sidebar and cache it
              try {
                final jsonResult =
                    await _controller.runJavaScriptReturningResult('''
                  (function() {
                    var links = Array.from(document.querySelectorAll('#sidebar a, .chapter a, ol.chapter a'));
                    var list = links.map(function(a) {
                      return {
                        "title": a.textContent.trim().replace(/\\s+/g, ' '),
                        "url": a.href
                      };
                    }).filter(function(item) {
                      return item.url && item.url.includes('rust-book.cs.brown.edu') && !item.url.includes('#');
                    });
                    return JSON.stringify(list);
                  })()
                ''');

                final decodedStr = _decodeWebViewResult(jsonResult);
                final List<dynamic> list = jsonDecode(decodedStr);
                final List<Map<String, String>> parsedChapters =
                    list.map((item) {
                  return {
                    'title': item['title'].toString(),
                    'url': item['url'].toString(),
                  };
                }).toList();

                if (parsedChapters.isNotEmpty) {
                  await _bookmarksService.saveChaptersIndex(parsedChapters);
                  _loadReadingMetrics();
                }
              } catch (_) {}

              // Update custom back/forward states based on DOM contents
              await _updateNavState();
            },
          ),
        );
      _loadInitialPage();
    }
  }

  /// Natively and decodes JSON-escaped string payloads returned by WebView script evaluations
  String _decodeWebViewResult(Object result) {
    final raw = result.toString();
    try {
      return jsonDecode(raw) as String;
    } catch (_) {
      // Fallback manual unescaping if raw content is not a strict JSON string
      if (raw.startsWith('"') && raw.endsWith('"') && raw.length >= 2) {
        return raw
            .substring(1, raw.length - 1)
            .replaceAll(r'\n', '\n')
            .replaceAll(r'\"', '"')
            .replaceAll(r'\\', r'\');
      }
      return raw;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _stopReadingTimeTracker();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _stopReadingTimeTracker();
    } else if (state == AppLifecycleState.resumed) {
      _startReadingTimeTracker();
    }
  }

  void _startReadingTimeTracker() {
    if (!_showDashboard) {
      _readerEntryTime = DateTime.now();
    }
  }

  void _stopReadingTimeTracker() {
    if (!_showDashboard && _readerEntryTime != null) {
      final elapsed = DateTime.now().difference(_readerEntryTime!).inSeconds;
      if (elapsed > 0) {
        _bookmarksService.addReadingTime(elapsed);
      }
      _readerEntryTime = null;
    }
  }

  Future<void> _loadReadingMetrics() async {
    final secs = await _bookmarksService.getReadingTimeSeconds();
    final read = await _bookmarksService.getReadChapters();
    final lastUrl = await _bookmarksService.getLastVisitedUrl();
    final index = await _bookmarksService.getChaptersIndex();

    // Background pre-fetching/caching to eliminate sheets launch lag!
    final bookmarks = await _bookmarksService.load();
    final apiKey = await _bookmarksService.getGeminiApiKey();
    final model = await _bookmarksService.getGeminiModel();
    final chatHistory = await _bookmarksService.loadChatHistory();
    String skill = '';
    try {
      skill = await rootBundle.loadString('assets/rust-skills/SKILL.md');
    } catch (_) {}

    if (mounted) {
      setState(() {
        _readingTimeSeconds = secs;
        _readChapters = read;
        _lastVisitedUrl = lastUrl;
        _cachedBookmarks = bookmarks;
        _cachedApiKey = apiKey;
        _cachedSelectedModel = model;
        _cachedChatHistory = chatHistory;
        _cachedSkillPrompt = skill;
        if (index.isNotEmpty) {
          _chapters = index;
        }
      });
    }
  }

  void _switchToReader(String url) {
    _stopReadingTimeTracker();
    setState(() {
      _showDashboard = false;
    });
    _startReadingTimeTracker();
    _loadPage(url);
    _loadReadingMetrics();
  }

  void _switchToDashboard() {
    _stopReadingTimeTracker();
    setState(() {
      _showDashboard = true;
    });
    _loadReadingMetrics();
  }

  Future<void> _loadInitialPage() async {
    if (_isTesting) return;
    try {
      final lastUrl = await _bookmarksService.getLastVisitedUrl();
      _loadPage(lastUrl);
    } catch (e) {
      _loadPage(_homeUrl);
    }
  }

  Future<void> _loadPage(String url) async {
    if (_isTesting) return;

    setState(() => _progress = 0.1);
    final isOnline = await _offlineCacheService.hasInternetConnection();

    if (isOnline) {
      await _controller.loadRequest(Uri.parse(url));
      // Save last visited url for progression caching
      await _bookmarksService.saveLastVisitedUrl(url);
    } else {
      final hasCache = await _offlineCacheService.hasCachedPage(url);
      if (hasCache) {
        final html = await _offlineCacheService.getCachedPage(url);
        if (html != null) {
          // Set base URL matching rust-book domains to let local resource resolutions succeed via WebView cache
          await _controller.loadHtmlString(html, baseUrl: url);
          await _bookmarksService.saveLastVisitedUrl(url);
        } else {
          await _controller.loadHtmlString(_getOfflineFallbackHtml(url));
        }
      } else {
        await _controller.loadHtmlString(_getOfflineFallbackHtml(url));
      }
    }
  }

  String _getOfflineFallbackHtml(String url) {
    return '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Offline Mode</title>
        <style>
          body {
            background-color: #121418;
            color: #d1d2d3;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            display: flex;
            align-items: center;
            justify-content: center;
            height: 100vh;
            margin: 0;
            padding: 24px;
            box-sizing: border-box;
          }
          .glass-panel {
            background: rgba(255, 255, 255, 0.02);
            border: 1px solid rgba(255, 255, 255, 0.06);
            border-radius: 20px;
            padding: 30px;
            text-align: center;
            max-width: 400px;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.4);
          }
          .icon {
            font-size: 48px;
            color: #de7b3f;
            margin-bottom: 16px;
          }
          h1 {
            font-size: 20px;
            margin: 0 0 10px 0;
            color: #ffffff;
            font-weight: 700;
          }
          p {
            font-size: 13px;
            line-height: 1.5;
            color: #8c8f94;
            margin: 0 0 20px 0;
          }
          .badge {
            display: inline-block;
            background: rgba(222, 123, 63, 0.12);
            border: 1px solid rgba(222, 123, 63, 0.25);
            color: #de7b3f;
            padding: 6px 12px;
            font-size: 11px;
            border-radius: 12px;
            font-weight: 600;
          }
        </style>
      </head>
      <body>
        <div class="glass-panel">
          <div class="icon">⚡</div>
          <h1>Offline Mode</h1>
          <p>You are reading offline. This chapter hasn't been cached yet. Visit it while connected to the internet to make it readable offline!</p>
          <div class="badge">Autosave is active when online</div>
        </div>
      </body>
      </html>
    ''';
  }

  Future<void> _updateNavState() async {
    if (_isTesting || !mounted) return;
    try {
      final back = await _controller.canGoBack();
      final fwd = await _controller.canGoForward();

      final hasPrevResult = await _controller.runJavaScriptReturningResult(
          "(() => { return !!(document.querySelector('a.previous') || document.querySelector('a[rel=\"prev\"]')); })()");
      final hasNextResult = await _controller.runJavaScriptReturningResult(
          "(() => { return !!(document.querySelector('a.next') || document.querySelector('a[rel=\"next\"]')); })()");

      final hasPrev =
          hasPrevResult.toString() == 'true' || hasPrevResult.toString() == '1';
      final hasNext =
          hasNextResult.toString() == 'true' || hasNextResult.toString() == '1';

      setState(() {
        _canGoBack = back || hasPrev;
        _canGoForward = fwd || hasNext;
      });
    } catch (e) {
      // Keep fallback state
    }
  }

  Future<void> _goBack() async {
    if (_isTesting) return;
    try {
      final prevClicked = await _controller.runJavaScriptReturningResult(
          "(() => { "
          "  var prevLink = document.querySelector('a.previous') || document.querySelector('a[rel=\"prev\"]');"
          "  if (prevLink) { prevLink.click(); return true; }"
          "  return false;"
          "})()");
      if (prevClicked.toString() != 'true' && prevClicked.toString() != '1') {
        if (await _controller.canGoBack()) {
          await _controller.goBack();
        }
      }
    } catch (e) {
      if (await _controller.canGoBack()) {
        await _controller.goBack();
      }
    }
  }

  Future<void> _goForward() async {
    if (_isTesting) return;
    try {
      final nextClicked = await _controller.runJavaScriptReturningResult(
          "(() => { "
          "  var nextLink = document.querySelector('a.next') || document.querySelector('a[rel=\"next\"]');"
          "  if (nextLink) { nextLink.click(); return true; }"
          "  return false;"
          "})()");
      if (nextClicked.toString() != 'true' && nextClicked.toString() != '1') {
        if (await _controller.canGoForward()) {
          await _controller.goForward();
        }
      }
    } catch (e) {
      if (await _controller.canGoForward()) {
        await _controller.goForward();
      }
    }
  }

  Future<void> _toggleBookmark() async {
    final nowMarked =
        await _bookmarksService.toggle(_currentUrl, _currentTitle);
    if (!mounted) return;
    setState(() => _bookmarked = nowMarked);
    _loadReadingMetrics();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom +
              82, // Floats cleanly directly above the bottom navbar!
          left: 24,
          right: 24,
        ),
        duration: const Duration(seconds: 1),
        content: GlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          borderRadius: BorderRadius.circular(16),
          blur: 12.0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FaIcon(
                nowMarked
                    ? FontAwesomeIcons.solidBookmark
                    : FontAwesomeIcons.bookmark,
                color:
                    const Color(0xFFFFB84D), // Amber Yellow bookmark alert icon
                size: 16,
              ),
              const SizedBox(width: 10),
              Text(
                nowMarked ? 'Added to Bookmarks' : 'Removed from Bookmarks',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openBookmarks() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BookmarksSheet(
        initialBookmarks: _cachedBookmarks,
        service: _bookmarksService,
        offlineCacheService: _offlineCacheService,
        controller: _controller,
        onSelect: (url) {
          Navigator.pop(context);
          if (!_isTesting) {
            _switchToReader(url);
          }
        },
      ),
    );
  }

  void _openGeminiChat() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => GeminiChatSheet(
        bookmarksService: _bookmarksService,
        webViewController:
            _controller, // Pass controller to load context in background
        cachedApiKey: _cachedApiKey,
        cachedSelectedModel: _cachedSelectedModel,
        cachedChatHistory: _cachedChatHistory,
        cachedSkillPrompt: _cachedSkillPrompt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inactiveIconColor = AppColors.textMuted.withValues(alpha: 0.4);

    // Custom glass neon colors for active buttons
    const Color navActiveColor =
        Color(0xFF2083A4); // Ocean Blue/Cyan for navigation
    final Color homeActiveColor = _showDashboard
        ? const Color(0xFFDE7B3F)
        : AppColors.textMuted.withValues(
            alpha: 0.4); // Rust Orange when on Dashboard, muted in Reader
    const Color listActiveColor =
        Color(0xFF9E8CF4); // Violet Purple for saved list
    const Color geminiActiveColor =
        Color(0xFFFFB84D); // Amber Yellow for Gemini sparkle icon
    const Color bookmarkActiveColor =
        Color(0xFFFFB84D); // Amber Yellow for bookmarks action

    return Container(
      decoration: const BoxDecoration(gradient: AppGradients.background),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset:
            false, // Disables WebView and circle background re-layouts on keyboard toggles to prevent animation lag!
        body: SafeArea(
          bottom: false, // Let full-screen content/orbits extend to screen edge
          child: Stack(
            children: [
              // 1. Drifting animated background circles
              const CirclesBackground(),

              // 2. Dashboard View & Full-screen WebView
              Positioned.fill(
                child: Stack(
                  children: [
                    // Dashboard layer
                    IgnorePointer(
                      ignoring: !_showDashboard,
                      child: AnimatedOpacity(
                        opacity: _showDashboard ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 380),
                        curve: Curves.easeInOutCubic,
                        child: AnimatedScale(
                          scale: _showDashboard ? 1.0 : 0.94,
                          duration: const Duration(milliseconds: 380),
                          curve: Curves.easeInOutCubic,
                          child: StudyDashboard(
                            readingTimeSeconds: _readingTimeSeconds,
                            readChapters: _readChapters,
                            lastVisitedUrl: _lastVisitedUrl,
                            chapters: _chapters,
                            searchController: _searchController,
                            onChapterSelect: _switchToReader,
                            bookmarksService: _bookmarksService,
                          ),
                        ),
                      ),
                    ),
                    // WebView Reader layer
                    IgnorePointer(
                      ignoring: _showDashboard,
                      child: AnimatedOpacity(
                        opacity: _showDashboard ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 380),
                        curve: Curves.easeInOutCubic,
                        child: AnimatedScale(
                          scale: _showDashboard ? 1.06 : 1.0,
                          duration: const Duration(milliseconds: 380),
                          curve: Curves.easeInOutCubic,
                          child: Column(
                            children: [
                              AnimatedOpacity(
                                opacity: _progress < 1 ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 300),
                                child: LinearProgressIndicator(
                                  value: _progress < 1 ? _progress : 1.0,
                                  minHeight: 2,
                                  backgroundColor: Colors.transparent,
                                  color: AppColors.rustOrange,
                                ),
                              ),
                              Expanded(
                                child: _isTesting
                                    ? const Center(
                                        child: Text("WebView Stub for Test"))
                                    : WebViewWidget(controller: _controller),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Floating Bottom Navbar on top of WebView
              Positioned(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 12,
                child: GlassContainer(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  borderRadius: BorderRadius.circular(30),
                  blur:
                      1.5, // Low blur (1.5) so text scrolling behind the navbar is clearly readable
                  child: Row(
                    children: [
                      GlassIconButton(
                        icon: FaIcon(
                          FontAwesomeIcons.chevronLeft,
                          size: 14,
                          color:
                              _canGoBack ? navActiveColor : inactiveIconColor,
                        ),
                        activeColor: navActiveColor,
                        tooltip: 'Previous Chapter / Back',
                        onTap: _canGoBack ? _goBack : null,
                      ),
                      const SizedBox(width: 8),
                      GlassIconButton(
                        icon: FaIcon(
                          FontAwesomeIcons.chevronRight,
                          size: 14,
                          color: _canGoForward
                              ? navActiveColor
                              : inactiveIconColor,
                        ),
                        activeColor: navActiveColor,
                        tooltip: 'Next Chapter / Forward',
                        onTap: _canGoForward ? _goForward : null,
                      ),
                      const SizedBox(width: 8),
                      GlassIconButton(
                        icon: FaIcon(
                          FontAwesomeIcons.house,
                          size: 14,
                          color: homeActiveColor,
                        ),
                        activeColor: homeActiveColor,
                        tooltip: 'Home Dashboard',
                        active: _showDashboard,
                        onTap: _switchToDashboard,
                      ),
                      const Spacer(),
                      // Center Sparkle icon button for Gemini Chat assistant
                      GlassIconButton(
                        icon: const Icon(
                          Icons.auto_awesome,
                          size: 16,
                          color: Color(0xFFFFB84D),
                        ),
                        activeColor: geminiActiveColor,
                        tooltip: 'Ask Gemini Tutor',
                        onTap: _openGeminiChat,
                      ),
                      const Spacer(),
                      GlassIconButton(
                        icon: const FaIcon(
                          FontAwesomeIcons.solidBookmark,
                          size: 14,
                          color: listActiveColor,
                        ),
                        activeColor: listActiveColor,
                        tooltip: 'Saved bookmarks',
                        onTap: _openBookmarks,
                      ),
                      const SizedBox(width: 8),
                      GlassIconButton(
                        icon: FaIcon(
                          _bookmarked
                              ? FontAwesomeIcons.solidBookmark
                              : FontAwesomeIcons.bookmark,
                          size: 14,
                          color: _showDashboard
                              ? inactiveIconColor
                              : bookmarkActiveColor,
                        ),
                        activeColor: bookmarkActiveColor,
                        tooltip: 'Bookmark this page',
                        active: !_showDashboard && _bookmarked,
                        onTap: _showDashboard ? null : _toggleBookmark,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
