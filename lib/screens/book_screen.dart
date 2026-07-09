/// Author: Amit (amitxd)
/// Description: Main book reader screen overlaying the WebView with a translucent glass navigation bar.
/// Handles offline caching, PROGRESS bookmarks, and launching the Gemini chat tutor sheet.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import '../services/bookmarks_service.dart';
import '../services/offline_cache_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/circles.dart';
import '../widgets/gemini_chat_sheet.dart';

class BookScreen extends StatefulWidget {
  const BookScreen({super.key});

  @override
  State<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends State<BookScreen> {
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

  bool get _isTesting => Platform.environment.containsKey('FLUTTER_TEST');

  @override
  void initState() {
    super.initState();
    if (!_isTesting) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (p) => setState(() => _progress = p / 100),
            onNavigationRequest: (request) {
              // Intercept inside-WebView links to route them through our offline caching handler!
              if (request.url.startsWith('https://rust-book.cs.brown.edu') || 
                  request.url.startsWith('http://rust-book.cs.brown.edu')) {
                _loadPage(request.url);
                return NavigationDecision.prevent; // Prevent default WebView loading
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
                      /* Aggressively force all theme variables and theme container classes to transparent */
                      :root, .theme-light, .theme-coal, .theme-navy, .theme-dark, .theme-rust {
                        --bg: transparent !important;
                        --sidebar-bg: rgba(18, 20, 24, 0.98) !important;
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
                      
                      /* Enable GPU compositor layer rasterization on root scroll containers to maximize scrolling performance */
                      html, body {
                        transform: translate3d(0,0,0) !important;
                        backface-visibility: hidden !important;
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
                        padding: 24px 24px 120px 24px !important;
                        max-width: 800px !important;
                        margin: 0 auto !important;
                      }
                      
                      ::-webkit-scrollbar {
                        width: 6px;
                      }
                      ::-webkit-scrollbar-thumb {
                        background: rgba(222, 123, 63, 0.35);
                        border-radius: 3px;
                      }
                      
                      /* Hide GitHub repository and Print/PDF buttons from the mdBook top header bar */
                      .git-repository-button, 
                      .print-button,
                      a[title*="Print"], 
                      a[aria-label*="Print"],
                      a[title*="Git"], 
                      a[aria-label*="Git"],
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
              final isOnline = await _offlineCacheService.hasInternetConnection();
              if (isOnline && !url.contains('data:text/html')) {
                try {
                  final htmlObj = await _controller.runJavaScriptReturningResult("document.documentElement.outerHTML");
                  final html = _decodeWebViewResult(htmlObj);
                  if (html.isNotEmpty && !html.contains("Offline Mode")) {
                    await _offlineCacheService.savePage(url, html);
                  }
                } catch (_) {}
              }

              // Update custom back/forward states based on DOM contents
              await _updateNavState();
            },
          ),
        );
      _loadInitialPage();
    }
  }

  /// Natively and robustly decodes JSON-escaped string payloads returned by WebView script evaluations
  String _decodeWebViewResult(Object result) {
    final raw = result.toString();
    try {
      return jsonDecode(raw) as String;
    } catch (_) {
      // Fallback manual unescaping if raw content is not a strict JSON string
      if (raw.startsWith('"') && raw.endsWith('"') && raw.length >= 2) {
        return raw.substring(1, raw.length - 1)
            .replaceAll(r'\n', '\n')
            .replaceAll(r'\"', '"')
            .replaceAll(r'\\', r'\');
      }
      return raw;
    }
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
        "(() => { return !!(document.querySelector('a.previous') || document.querySelector('a[rel=\"prev\"]')); })()"
      );
      final hasNextResult = await _controller.runJavaScriptReturningResult(
        "(() => { return !!(document.querySelector('a.next') || document.querySelector('a[rel=\"next\"]')); })()"
      );

      final hasPrev = hasPrevResult.toString() == 'true' || hasPrevResult.toString() == '1';
      final hasNext = hasNextResult.toString() == 'true' || hasNextResult.toString() == '1';

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
        "})()"
      );
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
        "})()"
      );
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

    // Premium floating glass toast alert (uses a slightly higher blur for read-accessibility overlay)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 82, // Floats cleanly directly above the bottom navbar!
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
                nowMarked ? FontAwesomeIcons.solidBookmark : FontAwesomeIcons.bookmark,
                color: const Color(0xFFFFB84D), // Amber Yellow bookmark alert icon
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
      builder: (_) => _BookmarksSheet(
        service: _bookmarksService,
        offlineCacheService: _offlineCacheService,
        controller: _controller,
        onSelect: (url) {
          Navigator.pop(context);
          if (!_isTesting) {
            _loadPage(url);
          }
        },
      ),
    );
  }

  void _openGeminiChat() {
    // Open the sheet immediately to eliminate user click/opening lag
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => GeminiChatSheet(
        bookmarksService: _bookmarksService,
        webViewController: _controller, // Pass controller to load context in background
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inactiveIconColor = AppColors.textMuted.withOpacity(0.4);

    // Custom glass neon colors for active buttons
    final Color navActiveColor = const Color(0xFF2083A4);      // Ocean Blue/Cyan for navigation
    final Color homeActiveColor = const Color(0xFFDE7B3F);     // Rust Orange for home
    final Color listActiveColor = const Color(0xFF9E8CF4);     // Violet Purple for saved list
    final Color geminiActiveColor = const Color(0xFFFFB84D);   // Amber Yellow for Gemini sparkle icon
    final Color bookmarkActiveColor = const Color(0xFFFFB84D); // Amber Yellow for bookmarks action

    return Container(
      decoration: const BoxDecoration(gradient: AppGradients.background),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false, // Disables WebView and circle background re-layouts on keyboard toggles to prevent animation lag!
        body: SafeArea(
          bottom: false, // Let full-screen content/orbits extend to screen edge
          child: Stack(
            children: [
              // 1. Drifting animated background circles
              const CirclesBackground(),
              
              // 2. Full-screen WebView so ebook text scrolls directly behind the bottom glass bar
              Positioned.fill(
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
                          ? const Center(child: Text("WebView Stub for Test"))
                          : WebViewWidget(controller: _controller),
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  borderRadius: BorderRadius.circular(30),
                  blur: 4.0, // Low blur (4.0) so text scrolling behind the navbar is clearly readable
                  child: Row(
                    children: [
                      GlassIconButton(
                        icon: FaIcon(
                          FontAwesomeIcons.chevronLeft,
                          size: 14,
                          color: _canGoBack ? navActiveColor : inactiveIconColor,
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
                          color: _canGoForward ? navActiveColor : inactiveIconColor,
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
                        tooltip: 'Home',
                        onTap: () {
                          if (!_isTesting) {
                            _loadPage(_homeUrl);
                          }
                        },
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
                        icon: FaIcon(
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
                          color: bookmarkActiveColor,
                        ),
                        activeColor: bookmarkActiveColor,
                        tooltip: 'Bookmark this page',
                        active: _bookmarked,
                        onTap: _toggleBookmark,
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

class _BookmarksSheet extends StatefulWidget {
  final BookmarksService service;
  final OfflineCacheService offlineCacheService;
  final WebViewController controller;
  final ValueChanged<String> onSelect;

  const _BookmarksSheet({
    required this.service,
    required this.offlineCacheService,
    required this.controller,
    required this.onSelect,
  });

  @override
  State<_BookmarksSheet> createState() => _BookmarksSheetState();
}

class _BookmarksSheetState extends State<_BookmarksSheet> {
  bool _isFullyCached = false;
  bool _isDownloading = false;
  int _downloadedCount = 0;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final cached = await widget.offlineCacheService.getBulkStatus();
    if (mounted) {
      setState(() {
        _isFullyCached = cached;
      });
    }
  }

  Future<void> _downloadAllPages({bool force = false}) async {
    // Check internet connection
    final isOnline = await widget.offlineCacheService.hasInternetConnection();
    if (!isOnline) {
      final bottomPadding = MediaQuery.of(context).padding.bottom;
      if (mounted) {
        Navigator.pop(context); // Close bookmarks sheet so warning toast is visible
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          margin: EdgeInsets.only(
            bottom: bottomPadding + 82, // Floats cleanly directly above the bottom navbar!
            left: 24,
            right: 24,
          ),
          duration: const Duration(seconds: 2),
          content: GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            borderRadius: BorderRadius.circular(16),
            blur: 12.0,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.wifi_off,
                  color: Color(0xFFFFB84D), // Amber Yellow warning color
                  size: 16,
                ),
                SizedBox(width: 10),
                Text(
                  'Internet connection required!',
                  style: TextStyle(
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
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadedCount = 0;
      _totalCount = 0;
    });

    try {
      // 1. Scrape all chapter links from sidebar Table of Contents inside WebView with resilient selector fallbacks
      final urlsObj = await widget.controller.runJavaScriptReturningResult(
        "(() => { "
        "  var links = Array.from(document.querySelectorAll('#sidebar a, .chapter a, nav a, ol.chapter a'));"
        "  if (links.length === 0) {"
        "    links = Array.from(document.querySelectorAll('a')).filter(a => a.href.includes('rust-book.cs.brown.edu'));"
        "  }"
        "  var urls = links.map(a => a.href).filter(h => h && h.startsWith('http'));"
        "  return JSON.stringify(Array.from(new Set(urls)));"
        "})()"
      );

      // Parse JSON string safely
      final rawStr = urlsObj.toString();
      String cleanJson = rawStr;
      if (cleanJson.startsWith('"') && cleanJson.endsWith('"')) {
        cleanJson = jsonDecode(cleanJson) as String;
      }
      
      final List<dynamic> urls = jsonDecode(cleanJson) as List<dynamic>;
      if (urls.isEmpty) {
        throw 'No chapter links found. Please wait for the book page to load first.';
      }

      setState(() {
        _totalCount = urls.length;
      });

      // 2. Fetch and cache pages sequentially
      final client = http.Client();
      for (final urlObj in urls) {
        final url = urlObj.toString();
        final alreadyCached = force ? false : await widget.offlineCacheService.hasCachedPage(url);
        if (!alreadyCached) {
          try {
            final response = await client.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
            if (response.statusCode == 200) {
              await widget.offlineCacheService.savePage(url, response.body);
            }
          } catch (_) {
            // Ignore single failures and continue caching remaining chapters
          }
        }

        if (!mounted) {
          client.close();
          return;
        }
        setState(() {
          _downloadedCount++;
        });
      }
      client.close();

      final bottomPadding = MediaQuery.of(context).padding.bottom;
      // 3. Mark book as fully cached
      await widget.offlineCacheService.saveBulkStatus(true);
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _isFullyCached = true;
        });
        Navigator.pop(context); // Close the bottom sheet so toast is visible on the main page
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          margin: EdgeInsets.only(
            bottom: bottomPadding + 82, // Floats cleanly directly above the bottom navbar!
            left: 24,
            right: 24,
          ),
          duration: const Duration(seconds: 2),
          content: GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            borderRadius: BorderRadius.circular(16),
            blur: 12.0,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.offline_pin,
                  color: Color(0xFF2083A4), // Ocean Blue/Cyan active icon color
                  size: 16,
                ),
                SizedBox(width: 10),
                Text(
                  'Book Downloaded for Offline!',
                  style: TextStyle(
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
    } catch (e) {
      final bottomPadding = MediaQuery.of(context).padding.bottom;
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
        Navigator.pop(context); // Close bookmarks sheet
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          margin: EdgeInsets.only(
            bottom: bottomPadding + 82, // Floats cleanly directly above the bottom navbar!
            left: 24,
            right: 24,
          ),
          duration: const Duration(seconds: 3),
          content: GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            borderRadius: BorderRadius.circular(16),
            blur: 12.0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.redAccent, // Red error color
                  size: 16,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Download failed: $e',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: GlassContainer(
        blur: 12.0,
        borderRadius: BorderRadius.circular(28),
        padding: const EdgeInsets.all(16),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const FaIcon(FontAwesomeIcons.solidBookmark,
                        color: Color(0xFFFFB84D), size: 16),
                    const SizedBox(width: 8),
                    Text('Bookmarks & Offline',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 12),
                // 1. Premium Glassmorphic Bulk Download Banner
                if (_isDownloading)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.06), width: 0.8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.rustOrange),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Downloading: $_downloadedCount / $_totalCount chapters...',
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: _totalCount > 0 ? _downloadedCount / _totalCount : 0.0,
                          backgroundColor: Colors.white.withOpacity(0.05),
                          color: AppColors.rustOrange,
                          minHeight: 3,
                        ),
                      ],
                    ),
                  )
                else if (_isFullyCached)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.offline_pin, color: Color(0xFF2083A4), size: 24),
                    title: const Text('Offline Ready', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: const Text('All book chapters are saved locally on this device.', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    trailing: IconButton(
                      icon: const Icon(Icons.sync, color: Color(0xFF2083A4), size: 20),
                      tooltip: 'Sync & Update Cache',
                      onPressed: () => _downloadAllPages(force: true),
                    ),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('The entire book is cached for offline reading!')),
                      );
                    },
                  )
                else
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.download_for_offline, color: AppColors.rustOrange, size: 24),
                    title: const Text('Download Entire Book', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: const Text('Cache all book chapters locally to read without internet.', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    onTap: _downloadAllPages,
                  ),
                const Divider(height: 16, color: AppColors.glassBorder),
                // 2. Bookmarks list
                Expanded(
                  child: FutureBuilder(
                    future: widget.service.load(),
                    builder: (context, snapshot) {
                      final items = snapshot.data ?? [];
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (items.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'No bookmarks yet — tap the bookmark icon while reading to save a page.',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      return ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 16,
                          color: AppColors.glassBorder,
                        ),
                        itemBuilder: (_, i) {
                          final b = items[i];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const FaIcon(FontAwesomeIcons.fileLines,
                                color: Color(0xFFFFB84D), size: 16),
                            title: Text(b.title,
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                            subtitle: Text(b.url,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: AppColors.textMuted, fontSize: 11)),
                            onTap: () => widget.onSelect(b.url),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
