/// Author: Amit (amitxd)
/// Description: A highly optimized glassmorphic bottom sheet containing the Gemini chat interface.
/// Postpones native bridge evaluations until after sheet transition to remove frame lag,
/// implements chat history serialization to persist tutor conversations, loads local mdBook context,
/// and dynamically bundles & injects Rust-specific skill guidelines (SKILL.md) into Gemini's system instructions.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:webview_flutter/webview_flutter.dart';
import '../services/bookmarks_service.dart';
import '../theme/app_theme.dart';
import 'glass_widgets.dart';

class GeminiChatSheet extends StatefulWidget {
  final BookmarksService bookmarksService;
  final WebViewController? webViewController; // Pass controller to scrape text asynchronously in background

  const GeminiChatSheet({
    key,
    required this.bookmarksService,
    this.webViewController,
  }) : super(key: key);

  @override
  State<GeminiChatSheet> createState() => _GeminiChatSheetState();
}

class _GeminiChatSheetState extends State<GeminiChatSheet> {
  final _keyController = TextEditingController();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  
  final List<Map<String, dynamic>> _messages = [];
  final List<String> _availableModels = [
    'gemini-3.1-flash-lite',
    'gemini-3.5-flash',
    'gemini-3-flash-preview',
    'gemini-3.1-pro-preview'
  ];
  
  String? _apiKey;
  String _selectedModel = 'gemini-3.1-flash-lite';
  ChatSession? _chatSession;
  bool _isLoading = false;
  bool _isConfiguring = false;

  @override
  void initState() {
    super.initState();
    // Postpone heavy preferences read and WebView JS evaluations by 350ms.
    // This allows the sheet to slide up in complete isolation, achieving a buttery-smooth, lag-free entrance animation!
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) {
        _loadApiKeyAndContext();
      }
    });
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

  Future<void> _loadApiKeyAndContext() async {
    // 1. Load active model selection from storage
    _selectedModel = await widget.bookmarksService.getGeminiModel();

    // 2. Try reading API key from process environment variable
    String? key = Platform.environment['GEMINI_API_KEY'];
    
    // 3. Try reading from cached preferences if not in environment
    if (key == null || key.isEmpty) {
      key = await widget.bookmarksService.getGeminiApiKey();
    }
    
    if (key != null && key.isNotEmpty) {
      if (mounted) {
        setState(() {
          _apiKey = key;
          _keyController.text = key!;
          _isConfiguring = false;
        });
      }
      
      // Fetch current chapter context text in the background while UI is already sliding up
      String? contextText;
      if (widget.webViewController != null) {
        try {
          final result = await widget.webViewController!.runJavaScriptReturningResult(
            "document.querySelector('main')?.innerText || document.body.innerText"
          );
          contextText = _decodeWebViewResult(result);
        } catch (_) {
          // Fallback to no page context
        }
      }
      
      _initGemini(key, contextText);
    } else {
      if (mounted) {
        setState(() {
          _isConfiguring = true;
        });
      }
    }
  }

  Future<void> _initGemini(String apiKey, String? contextText) async {
    // Load local rust-skills instruction rules (SKILL.md) dynamically from the asset bundle
    String? skillPrompt;
    try {
      skillPrompt = await rootBundle.loadString('assets/rust-skills/SKILL.md');
    } catch (_) {
      // Fallback to empty context if asset loader fails or during unit testing stubs
    }

    try {
      final model = GenerativeModel(
        model: _selectedModel, // Dynamically use the selected model
        apiKey: apiKey,
        systemInstruction: Content.system(
          "You are an assistant built inside a Rust Book reading app. "
          "You are helpfully explaining Rust concepts, compiler errors, code syntax, and logic. "
          "Keep answers concise, clear, and direct. Use markdown lists, code blocks, and bold tags for formatting. "
          "${skillPrompt != null && skillPrompt.isNotEmpty ? '\n\nHere are some comprehensive Rust coding rules and best practices guidelines to strictly follow:\n---\n$skillPrompt\n---\nUse these guidelines when generating, explaining, or reviewing code.' : ''}"
          "${contextText != null && contextText.isNotEmpty ? '\n\nHere is the text content of the page the user is currently reading for context:\n---\n$contextText\n---\nRefer to this text when answering questions about the current page.' : ''}"
        ),
      );

      // Load conversation history from disk storage
      final history = await widget.bookmarksService.loadChatHistory();
      
      // Reconstruct matching Content items to load into model's chat history session
      final List<Content> apiHistory = [];
      for (final msg in history) {
        final isUser = msg['isUser'] as bool;
        final text = msg['text'] as String;
        apiHistory.add(
          isUser ? Content.text(text) : Content.model([TextPart(text)]),
        );
      }

      _chatSession = model.startChat(history: apiHistory);
      
      if (mounted) {
        setState(() {
          _messages.clear();
          if (history.isNotEmpty) {
            // Re-populate and compile formatting widgets for loaded chat bubbles
            _messages.addAll(history.map((m) {
              return {
                'text': m['text'],
                'isUser': m['isUser'],
                if (m.containsKey('isError')) 'isError': m['isError'],
                'widget': _buildFormattedMessage(m['text'] as String, m['isUser'] as bool),
              };
            }));
          } else {
            // Cache welcoming message if history is empty
            final welcomeText = "Hi! I'm Gemini (using $_selectedModel). Ask me anything about ownership, lifetimes, or compiler errors as you read!";
            _messages.add({
              'text': welcomeText,
              'isUser': false,
              'widget': _buildFormattedMessage(welcomeText, false),
            });
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initialize Gemini: $e')),
      );
    }
  }

  Future<void> _saveConfig() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) return;
    
    await widget.bookmarksService.saveGeminiApiKey(key);
    await widget.bookmarksService.saveGeminiModel(_selectedModel);
    
    setState(() {
      _apiKey = key;
      _isConfiguring = false;
      _messages.clear();
    });
    
    // Clear chat history on config reset to start fresh
    await widget.bookmarksService.saveChatHistory([]);
    
    // Fetch context asynchronously on custom key save
    String? contextText;
    if (widget.webViewController != null) {
      try {
        final result = await widget.webViewController!.runJavaScriptReturningResult(
          "document.querySelector('main')?.innerText || document.body.innerText"
        );
        contextText = _decodeWebViewResult(result);
      } catch (_) { }
    }
    _initGemini(key, contextText);
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _chatSession == null || _isLoading) return;

    // Cache the precompiled user message widget immediately on submit
    final userWidget = _buildFormattedMessage(text, true);

    setState(() {
      _messages.add({
        'text': text,
        'isUser': true,
        'widget': userWidget,
      });
      _messageController.clear();
      _isLoading = true;
    });

    try {
      final response = await _chatSession!.sendMessage(Content.text(text));
      final reply = response.text ?? "I received an empty response.";
      
      // Cache the precompiled Gemini reply widget immediately on receive
      final botWidget = _buildFormattedMessage(reply, false);
      setState(() {
        _messages.add({
          'text': reply,
          'isUser': false,
          'widget': botWidget,
        });
      });

      // Persist the entire updated conversation history to disk vault
      await widget.bookmarksService.saveChatHistory(_messages);
    } catch (e) {
      final errorText = "Sorry, I ran into an error generating that response: $e";
      final errWidget = _buildFormattedMessage(errorText, false);
      setState(() {
        _messages.add({
          'text': errorText,
          'isUser': false,
          'isError': true,
          'widget': errWidget,
        });
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Clears the chat conversation history completely in memory and on disk
  Future<void> _clearChatHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF14161C),
        title: const Text('Clear Chat History?', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to clear your conversation with the Gemini tutor?', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rustOrange),
            child: const Text('Clear', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.bookmarksService.saveChatHistory([]);
      if (_apiKey != null) {
        // Re-initialize a clean Gemini session
        _messages.clear();
        _initGemini(_apiKey!, null);
      }
    }
  }

  void _openAiStudio() async {
    final url = Uri.parse('https://aistudio.google.com/app/api-keys');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: GlassContainer(
        // Set blur to 0.0 to completely disable expensive BackdropFilter comp redraw overhead on WebView, fixing scroll/type/keyboard lag
        blur: 0.0,
        borderRadius: BorderRadius.circular(28),
        fillColor: const Color(0xFF14161C), // Solid 100% opaque obsidian dark panel to guarantee maximum scroll performance
        padding: const EdgeInsets.all(16),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.65,
            ),
            child: _isConfiguring ? _buildConfigView() : _buildChatView(),
          ),
        ),
      ),
    );
  }

  Widget _buildConfigView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, color: Color(0xFFFFB84D), size: 18),
            const SizedBox(width: 8),
            Text(
              'Gemini Assistant Settings',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Choose your model and enter your Gemini API Key. Your settings are saved locally on your device.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 16),
        // 1. Gorgeous glass model selector dropdown
        DropdownButtonFormField<String>(
          value: _selectedModel,
          dropdownColor: const Color(0xFF14161C),
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            labelText: 'Model Selection',
            labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            filled: true,
            fillColor: Colors.white.withOpacity(0.04),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.rustOrange),
            ),
          ),
          items: _availableModels.map((m) {
            return DropdownMenuItem<String>(
              value: m,
              child: Text(m),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedModel = val);
            }
          },
        ),
        const SizedBox(height: 12),
        // 2. API key text input
        TextField(
          controller: _keyController,
          obscureText: true,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            labelText: 'Gemini API Key',
            labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            hintText: 'Enter your Gemini API Key...',
            hintStyle: TextStyle(color: AppColors.textMuted.withOpacity(0.5)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.04),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.rustOrange),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Flexible(
              child: TextButton.icon(
                onPressed: _openAiStudio,
                icon: const Icon(Icons.open_in_new, size: 14, color: Color(0xFF2083A4)),
                label: const Text(
                  'Get Free Key',
                  style: TextStyle(
                    color: Color(0xFF2083A4), 
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _saveConfig,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.rustOrange,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              child: const Text('Save & Start', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildChatView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, color: Color(0xFFFFB84D), size: 16),
            const SizedBox(width: 8),
            Text(
              'Gemini Tutor',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
            ),
            const Spacer(),
            // Trash bin icon button to clear chat history completely
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.textMuted),
              tooltip: 'Clear Chat History',
              onPressed: _clearChatHistory,
            ),
            IconButton(
              icon: const Icon(Icons.settings, size: 16, color: AppColors.textMuted),
              tooltip: 'Settings',
              onPressed: () => setState(() => _isConfiguring = true),
            ),
          ],
        ),
        const Divider(height: 16, color: AppColors.glassBorder),
        Flexible(
          child: ListView.separated(
            controller: _scrollController,
            // Reversing the list puts index 0 at the bottom.
            // This natively attaches new messages to the bottom and pushes the list up on keyboard resize with exactly zero scroll lag!
            reverse: true,
            itemCount: _messages.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              // Retrieve elements in reverse order to preserve chronological top-to-bottom layout
              final msg = _messages[_messages.length - 1 - i];
              final isUser = msg['isUser'] as bool;
              final isErr = msg['isError'] == true;
              final Widget formattedWidget = msg['widget'] as Widget;

              return _FadeInMessage(
                key: ValueKey(msg),
                child: Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.78,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isUser ? 16 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 16),
                      ),
                      color: isUser
                          ? const Color(0xFF9E8CF4).withOpacity(0.08)
                          : isErr 
                              ? Colors.red.withOpacity(0.08)
                              : const Color(0xFFDE7B3F).withOpacity(0.08),
                      border: Border.all(
                        color: isUser
                            ? const Color(0xFF9E8CF4).withOpacity(0.15)
                            : isErr
                                ? Colors.red.withOpacity(0.15)
                                : const Color(0xFFDE7B3F).withOpacity(0.15),
                        width: 0.8,
                      ),
                    ),
                    child: formattedWidget,
                  ),
                ),
              );
            },
          ),
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFFFFB84D)),
                ),
                SizedBox(width: 8),
                Text('Gemini is thinking...', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
        const Divider(height: 16, color: AppColors.glassBorder),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Ask about lifetimes, variable rules, ownership...',
                  hintStyle: TextStyle(color: AppColors.textMuted.withOpacity(0.4), fontSize: 12),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.03),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: Color(0xFFFFB84D)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GlassIconButton(
              icon: const Icon(Icons.send, size: 14, color: Colors.white),
              activeColor: const Color(0xFFFFB84D),
              onTap: _sendMessage,
            ),
          ],
        ),
      ],
    );
  }

  /// Markdown renderer to style text, lists, bold elements, and block/inline code blocks
  Widget _buildFormattedMessage(String text, bool isUser) {
    if (isUser) {
      return Text(
        text,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.4),
      );
    }

    // Use flutter_markdown with our custom CodeElementBuilder for rich syntax highlighting
    return MarkdownBody(
      data: text,
      selectable: true,
      builders: {
        'code': CodeElementBuilder(),
      },
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.5),
        strong: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        em: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13),
        h1: const TextStyle(color: Color(0xFFFFB84D), fontSize: 16, fontWeight: FontWeight.bold, height: 1.6),
        h2: const TextStyle(color: Color(0xFFFFB84D), fontSize: 15, fontWeight: FontWeight.bold, height: 1.5),
        h3: const TextStyle(color: Color(0xFFFFB84D), fontSize: 14, fontWeight: FontWeight.bold, height: 1.4),
        listBullet: const TextStyle(color: AppColors.rustOrange, fontSize: 13),
        code: const TextStyle(
          color: Color(0xFFFFB84D),
          fontFamily: 'monospace',
          fontSize: 12,
          backgroundColor: Colors.transparent,
        ),
      ),
    );
  }
}

/// Custom code element builder that integrates flutter_highlight for syntax highlighting inside Markdown fenced code blocks
class CodeElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final codeContent = element.textContent;

    // Fallback to default inline code styling if it is inline (no newlines present)
    if (!codeContent.contains('\n')) {
      return null;
    }

    // Extract language from className (e.g. "language-rust")
    var language = 'rust'; // Default to rust in our book app
    if (element.attributes['class'] != null) {
      String lg = element.attributes['class'] as String;
      if (lg.startsWith('language-')) {
        language = lg.substring(9);
      }
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.28),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 0.8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: HighlightView(
          codeContent.trim(),
          language: language,
          theme: atomOneDarkTheme,
          padding: const EdgeInsets.all(12),
          textStyle: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

/// Lightweight slide-up and fade-in entry animation for messages
class _FadeInMessage extends StatelessWidget {
  final Widget child;

  const _FadeInMessage({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1.0 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
