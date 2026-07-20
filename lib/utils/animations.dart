import 'package:flutter/material.dart';

class SlideTransitionPage extends PageRouteBuilder {
  SlideTransitionPage({
    required Widget child,
    Curve curve = Curves.easeOut,
    Duration duration = const Duration(milliseconds: 300),
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeOut;

            final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
          transitionDuration: duration,
        );
}

class FadeTransitionPage extends PageRouteBuilder {
  FadeTransitionPage({
    required Widget child,
    Curve curve = Curves.easeOut,
    Duration duration = const Duration(milliseconds: 300),
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation.drive(CurveTween(curve: curve)),
              child: child,
            );
          },
          transitionDuration: duration,
        );
}

class ScaleTransitionPage extends PageRouteBuilder {
  ScaleTransitionPage({
    required Widget child,
    Curve curve = Curves.easeOut,
    Duration duration = const Duration(milliseconds: 300),
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return ScaleTransition(
              scale: animation.drive(Tween(begin: 0.9, end: 1.0).chain(CurveTween(curve: curve))),
              child: child,
            );
          },
          transitionDuration: duration,
        );
}

class FlipCard extends StatefulWidget {
  final Widget front;
  final Widget back;
  final bool isFlipped;
  final Duration duration;

  const FlipCard({
    super.key,
    required this.front,
    required this.back,
    this.isFlipped = false,
    this.duration = const Duration(milliseconds: 400),
  });

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
    if (widget.isFlipped) {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant FlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFlipped != oldWidget.isFlipped) {
      if (widget.isFlipped) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final isFront = _animation.value < 0.5;
        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(_animation.value * 3.14159),
          alignment: Alignment.center,
          child: isFront ? widget.front : Transform.flip(flipX: true, child: widget.back),
        );
      },
    );
  }
}

class AnswerFeedbackAnimation extends StatefulWidget {
  final bool isCorrect;
  final Widget child;

  const AnswerFeedbackAnimation({
    super.key,
    required this.isCorrect,
    required this.child,
  });

  @override
  State<AnswerFeedbackAnimation> createState() => _AnswerFeedbackAnimationState();
}

class _AnswerFeedbackAnimationState extends State<AnswerFeedbackAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).chain(CurveTween(curve: const Interval(0, 0.3))).animate(_controller);
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: const Interval(0.3, 1.0))).animate(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.scale(
          scale: _scaleAnimation.value,
          child: widget.child,
        ),
        FadeTransition(
          opacity: _opacityAnimation,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.isCorrect ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(
              widget.isCorrect ? Icons.check : Icons.close,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
      ],
    );
  }
}

class ShakeAnimation extends StatefulWidget {
  final Widget child;
  final int durationMs;

  const ShakeAnimation({
    super.key,
    required this.child,
    this.durationMs = 500,
  });

  @override
  State<ShakeAnimation> createState() => _ShakeAnimationState();
}

class _ShakeAnimationState extends State<ShakeAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: widget.durationMs),
      vsync: this,
    );
    _animation = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticInOut,
      ),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_animation.value, 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class ProgressBarAnimation extends StatelessWidget {
  final double progress;
  final Color color;
  final Duration duration;

  const ProgressBarAnimation({
    super.key,
    required this.progress,
    required this.color,
    this.duration = const Duration(milliseconds: 500),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: progress),
      duration: duration,
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Container(
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Container(
            width: value,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      },
    );
  }
}