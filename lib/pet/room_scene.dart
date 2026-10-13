import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../core/models.dart';
import 'pet_drawing.dart';

class RoomScene extends StatefulWidget {
  const RoomScene({
    super.key,
    required this.pet,
    required this.focusing,
    required this.onInteract,
    required this.mealCount,
    this.showMeal = false,
  });
  final PetState pet;
  final bool focusing, showMeal;
  final int mealCount;
  final void Function(String) onInteract;
  @override
  State<RoomScene> createState() => RoomSceneState();
}

class RoomSceneState extends State<RoomScene> {
  late final PetRoomGame game;
  @override
  void initState() {
    super.initState();
    game = PetRoomGame(
      widget.pet,
      widget.focusing,
      (action) => widget.onInteract(action),
    );
    if (widget.showMeal) game.react('meal');
  }

  @override
  void didUpdateWidget(RoomScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    game.pet = widget.pet;
    game.focusing = widget.focusing;
    if (widget.mealCount > oldWidget.mealCount) game.react('meal');
  }

  void interact(String action) {
    if (widget.focusing || widget.pet.dead) return;
    game.react(action);
    widget.onInteract(action);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: '宠物小屋。可使用下方按钮抚摸、玩球或休息。',
    child: AspectRatio(
      aspectRatio: 1.5,
      child: GestureDetector(
        onTapDown: (details) => game.tap(details.localPosition),
        child: ClipRect(child: GameWidget(game: game)),
      ),
    ),
  );
}

// Source: https://docs.flame-engine.org/latest/flame/game_widget.html
// Animation-only: feeding and hunger never depend on frame updates.
class PetRoomGame extends FlameGame {
  PetRoomGame(this.pet, this.focusing, this.onInteract);
  PetState pet;
  bool focusing;
  final void Function(String) onInteract;
  final _random = math.Random(7);
  ui.Image? _background;
  Offset _position = const Offset(530, 470);
  Offset _target = const Offset(530, 470);
  static const bed = Offset(205, 440);
  static const ball = Offset(753, 516);
  static const bowl = Offset(850, 431);
  double _time = 0, _wander = 0, _reactionUntil = 0;
  String _reaction = '';
  bool _napping = false;
  final _floor = Path()
    ..moveTo(105, 460)
    ..lineTo(440, 315)
    ..lineTo(888, 441)
    ..lineTo(570, 601)
    ..close();
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _background = await images.load('room.png');
  }

  @override
  Color backgroundColor() => const Color(0xFFFAF3E5);
  double get _scale => math.min(size.x / 1000, size.y / (2000 / 3));
  Offset get _origin =>
      Offset((size.x - 1000 * _scale) / 2, (size.y - (2000 / 3) * _scale) / 2);
  void tap(Offset local) {
    if (focusing || pet.dead || _scale <= 0) return;
    final point = (local - _origin) / _scale;
    if ((point - (_position - const Offset(0, 50))).distance < 80) {
      react('pet');
      onInteract('pet');
    } else if ((point - ball).distance < 45) {
      react('ball');
      onInteract('ball');
    } else if ((point - bed).distance < 80) {
      react('rest');
      onInteract('rest');
    } else if (_floor.contains(point)) {
      _target = point;
      _napping = false;
      _wander = 0;
      _reaction = '我来啦';
      _reactionUntil = _time + 2;
      onInteract('move');
    }
  }

  void react(String action) {
    if (focusing || pet.dead) return;
    _reactionUntil = _time + 4;
    _reaction = switch (action) {
      'ball' => '一起玩吧！',
      'rest' => '呼噜…',
      'meal' => '吃饱啦！',
      _ => '喜欢你 ♡',
    };
    _napping = action == 'rest';
    if (action == 'ball') _target = ball - const Offset(45, 0);
    if (action == 'rest') _target = bed;
    if (action == 'meal') _target = bowl - const Offset(55, 0);
    _wander = -4;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    if (pet.dead) return;
    if (focusing) {
      _target = bed;
    } else {
      _wander += dt;
      if (_wander > 7 && !_napping && pet.hungryDays < 5) {
        _wander = 0;
        _target = [
          const Offset(390, 425),
          const Offset(550, 485),
          const Offset(670, 450),
          const Offset(520, 520),
        ][_random.nextInt(4)];
      }
    }
    final delta = _target - _position;
    if (delta.distance > 2) {
      _position +=
          delta /
          delta.distance *
          math.min(delta.distance, dt * (40 + 35 * pet.energy));
    }
  }

  void _label(Canvas canvas, String text, Offset at) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontFamily: 'Microsoft YaHei',
          fontSize: 18,
          color: Color(0xFF5E4938),
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.save();
    canvas.translate(_origin.dx, _origin.dy);
    canvas.scale(_scale);
    final background = _background;
    if (background != null) {
      canvas.drawImageRect(
        background,
        Rect.fromLTWH(
          0,
          0,
          background.width.toDouble(),
          background.height.toDouble(),
        ),
        const Rect.fromLTWH(0, 0, 1000, 2000 / 3),
        Paint(),
      );
    }
    if (!pet.dead) {
      final resting =
          (focusing || _napping) && (_position - _target).distance < 8;
      drawPet(
        canvas,
        _position,
        1.05,
        pet,
        sleeping: resting,
        motion: _time,
        happy: _time < _reactionUntil && _reaction != '呼噜…',
      );
      if (_time < _reactionUntil && !focusing) {
        final bubble = Rect.fromCenter(
          center: _position - const Offset(0, 170),
          width: 155,
          height: 42,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(bubble, const Radius.circular(18)),
          Paint()..color = const Color(0xFFFFFEF7),
        );
        _label(canvas, _reaction, bubble.center);
      }
      if (resting) _label(canvas, 'z Z', _position + const Offset(70, -110));
      if (_time < _reactionUntil && _reaction == '吃饱啦！') {
        for (var i = 0; i < 5; i++) {
          canvas.drawCircle(
            Offset(845 + i * 5, 434 + (i % 2) * 4),
            4,
            Paint()..color = const Color(0xFF9D7145),
          );
        }
      }
    }
    canvas.restore();
  }
}
