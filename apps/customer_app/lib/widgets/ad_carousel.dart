import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../models/advertisement.dart';
import '../services/ad_stats_service.dart';

/// لوحة إعلانات فيديو Premium أعلى الصفحة الرئيسية — Carousel أفقي
/// قابل للسحب، كل صفحة فيديو مستقل. لا تُهيَّأ (initialize) أي فيديو
/// إلا لحظة أن تصبح صفحته هي الظاهرة فعليًا على الشاشة، ويُتخلَّص من
/// المُتحكِّم (dispose) فور مغادرتها — لا تحميل كل الفيديوهات دفعة
/// واحدة، ولا أكثر من فيديو واحد يعمل في نفس اللحظة أبدًا.
class AdCarousel extends StatefulWidget {
  final List<Advertisement> ads;

  const AdCarousel({super.key, required this.ads});

  @override
  State<AdCarousel> createState() => _AdCarouselState();
}

class _AdCarouselState extends State<AdCarousel> {
  final _pageController = PageController();
  int _currentPage = 0;
  final _viewedAdIds = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recordView(0));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _recordView(int index) {
    if (index < 0 || index >= widget.ads.length) return;
    final adId = widget.ads[index].id;
    // مرة واحدة فقط لكل إعلان طوال بقاء هذه الشاشة مفتوحة — لا نُحصي
    // نفس المشاهدة مرارًا عند التمرير جيئة وذهابًا بين نفس الإعلانات.
    if (_viewedAdIds.add(adId)) {
      AdStatsService.recordView(adId);
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _recordView(index);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ads.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.ads.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: _AdVideoPage(
                      ad: widget.ads[index],
                      isActivePage: index == _currentPage,
                    ),
                  ),
                );
              },
            ),
          ),
          if (widget.ads.length > 1) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.ads.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _currentPage ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _currentPage
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface
                                .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AdVideoPage extends StatefulWidget {
  final Advertisement ad;
  final bool isActivePage;

  const _AdVideoPage({required this.ad, required this.isActivePage});

  @override
  State<_AdVideoPage> createState() => _AdVideoPageState();
}

class _AdVideoPageState extends State<_AdVideoPage>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _initializing = false;
  bool _failed = false;
  bool _muted = true;
  bool _completionArmed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.isActivePage) _initializeController();
  }

  @override
  void didUpdateWidget(covariant _AdVideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActivePage && !oldWidget.isActivePage) {
      _initializeController();
    } else if (!widget.isActivePage && oldWidget.isActivePage) {
      _disposeController();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      controller.pause();
    } else if (state == AppLifecycleState.resumed && widget.isActivePage) {
      controller.play();
    }
  }

  Future<void> _initializeController() async {
    if (_controller != null || _initializing) return;

    setState(() {
      _initializing = true;
      _failed = false;
    });

    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.ad.videoUrl),
      );
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(_muted ? 0 : 1);
      controller.addListener(_onControllerTick);

      if (!mounted || !widget.isActivePage) {
        controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _initializing = false;
      });
      await controller.play();
      AdStatsService.recordVideoStart(widget.ad.id);
    } catch (_) {
      // ضعف إنترنت، رابط فيديو غير صالح، إلخ — نعرض الصورة المصغّرة
      // فقط بدل تعطيل الشاشة كلها.
      if (mounted) {
        setState(() {
          _initializing = false;
          _failed = true;
        });
      }
    }
  }

  void _onControllerTick() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    final position = controller.value.position;
    final duration = controller.value.duration;
    if (duration.inMilliseconds == 0) return;

    final remaining = duration - position;
    if (remaining.inMilliseconds < 300 && _completionArmed) {
      _completionArmed = false;
      AdStatsService.recordVideoCompletion(widget.ad.id);
    } else if (position.inMilliseconds < 300) {
      // عاد الفيديو لبدايته (Loop جديد) — نسمح بتسجيل اكتمال جديد لاحقًا.
      _completionArmed = true;
    }
  }

  void _disposeController() {
    final controller = _controller;
    if (controller == null) return;
    controller.removeListener(_onControllerTick);
    controller.pause();
    controller.dispose();
    if (mounted) {
      setState(() => _controller = null);
    } else {
      _controller = null;
    }
  }

  void _togglePlayPause() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    setState(() {
      controller.value.isPlaying ? controller.pause() : controller.play();
    });
  }

  void _toggleMute() {
    final controller = _controller;
    setState(() => _muted = !_muted);
    controller?.setVolume(_muted ? 0 : 1);
  }

  Future<void> _openLink() async {
    final url = widget.ad.linkUrl;
    if (url == null || url.isEmpty) return;

    AdStatsService.recordClick(widget.ad.id);

    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final controller = _controller;
    if (controller != null) {
      controller.removeListener(_onControllerTick);
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;

    return GestureDetector(
      onTap: ready ? _togglePlayPause : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // الطبقة الخلفية: الصورة المصغّرة دائمًا موجودة كخلفية احتياطية
          // (قبل التشغيل، أثناء التحميل، أو إن فشل الفيديو).
          if (widget.ad.thumbnailUrl != null)
            Image.network(
              widget.ad.thumbnailUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Container(color: Colors.black87),
            )
          else
            Container(color: Colors.black87),

          if (ready)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            ),

          if (_initializing)
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          if (_failed)
            const Positioned(
              bottom: 12,
              right: 12,
              child: Icon(
                Icons.wifi_off_rounded,
                color: Colors.white70,
                size: 20,
              ),
            ),

          // تدرّج سفلي لضمان وضوح النص فوق أي فيديو/صورة.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.75),
                  ],
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.ad.advertiserName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.ad.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.ad.linkUrl != null &&
                      widget.ad.linkUrl!.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    _CtaButton(onTap: _openLink),
                  ],
                ],
              ),
            ),
          ),

          // أزرار التحكم (كتم/إلغاء كتم) أعلى يمين البطاقة.
          if (ready)
            Positioned(
              top: 10,
              left: 10,
              child: _IconChip(
                icon: _muted
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
                onTap: _toggleMute,
              ),
            ),
        ],
      ),
    );
  }
}

class _CtaButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CtaButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Text(
            'زيارة',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconChip({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black45,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
      ),
    );
  }
}
