import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';
import 'dart:math';

void main() {
  final miJuego = SpaceImpactRemake();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: GameWidget(
          game: miJuego,
          overlayBuilderMap: {
            'MenuInicio': (context, SpaceImpactRemake game) => MenuInicio(game: game),
          },
          initialActiveOverlays: const ['MenuInicio'],
        ),
      ),
    ),
  );
}

// --- INTERFAZ DEL MENÚ ---

class MenuInicio extends StatelessWidget {
  final SpaceImpactRemake game;
  const MenuInicio({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'GALAXY IMPACT\n2322',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.cyanAccent,
                fontSize: 40,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 50),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
              ),
              onPressed: () => game.iniciarPartida(),
              child: const Text(
                'INICIAR JUEGO',
                style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- LÓGICA DEL JUEGO ---

class SpaceImpactRemake extends FlameGame with DragCallbacks, HasCollisionDetection {
  Player? nave;
  int puntos = 0;
  int vidas = 5; 
  int nivel = 1;
  int enemigosEliminados = 0;
  bool estaJugando = false; 
  bool jefeActivo = false;
  late TextComponent uiText;

  @override
  Future<void> onLoad() async {
    add(RectangleComponent(size: size, paint: Paint()..color = const Color(0xFF0D0D0D)));
    for (int i = 0; i < 35; i++) add(EstrellaFondo());

    uiText = TextComponent(
      text: '',
      position: Vector2(20, 40),
      textRenderer: TextPaint(
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
    add(uiText);
  }

  void iniciarPartida() {
    overlays.remove('MenuInicio');
    
    // Limpiar componentes de partidas previas
    children.where((c) => c is Enemigo || c is Bala || c is JefeFinal || c is GameoverPanel || c is TimerComponent || c is BalaJefe)
            .forEach((c) => c.removeFromParent());
    
    puntos = 0;
    vidas = 5; 
    nivel = 1;
    enemigosEliminados = 0;
    estaJugando = true;
    jefeActivo = false;

    nave = Player();
    add(nave!);

    add(TimerComponent(period: 0.4, repeat: true, onTick: disparar));
    add(TimerComponent(period: 1.5, repeat: true, onTick: crearEnemigo));
  }

  void disparar() {
    if (estaJugando && nave != null && nave!.isMounted) {
      Vector2 posicionCanyon = nave!.position + Vector2(nave!.size.x, nave!.size.y / 2);
      for (int i = 0; i < nivel; i++) {
        double anguloCalculado = (i - (nivel - 1) / 2) * 0.15;
        add(Bala(posicionInicial: posicionCanyon.clone(), angulo: anguloCalculado));
      }
    }
  }

  void crearEnemigo() {
    if (!estaJugando || jefeActivo) return;
    if (nivel >= 5) {
      if (children.whereType<JefeFinal>().isEmpty) {
        jefeActivo = true;
        add(JefeFinal());
      }
    } else {
      add(Enemigo(velocidad: 150.0 + (nivel * 35)));
    }
  }

  void registrarBaja() {
    enemigosEliminados++;
    puntos += 10;
    if (enemigosEliminados % 10 == 0 && nivel < 5) {
      nivel++;
      vidas++;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (estaJugando) {
      uiText.text = 'Nivel: $nivel | Puntos: $puntos | Vidas: $vidas';
      if (vidas <= 0) finDelJuego();
    }
  }

  void finDelJuego() {
    estaJugando = false;
    nave?.removeFromParent();
    add(GameoverPanel(puntos: puntos, victoria: false));
  }

  void victoria() {
    estaJugando = false;
    add(GameoverPanel(puntos: puntos, victoria: true));
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (estaJugando && nave != null) {
      nave!.position.add(event.localDelta);
      nave!.position.clamp(Vector2.zero(), size - nave!.size);
    }
  }
}

// --- COMPONENTES ---

class Player extends PositionComponent with HasGameRef<SpaceImpactRemake>, CollisionCallbacks {
  Player() : super(size: Vector2(70, 50), position: Vector2(50, 200));

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox());
    try {
      final sprite = await gameRef.loadSprite('nave.png');
      add(SpriteComponent(sprite: sprite, size: size));
    } catch (e) {
      add(PolygonComponent([Vector2(0, 0), Vector2(size.x, size.y / 2), Vector2(0, size.y)], paint: Paint()..color = Colors.blueAccent));
    }
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Enemigo || other is JefeFinal || other is BalaJefe) {
      gameRef.vidas--;
      if (other is! JefeFinal) other.removeFromParent();
    }
  }
}

class JefeFinal extends PositionComponent with HasGameRef<SpaceImpactRemake>, CollisionCallbacks {
  static const double vidaMaxima = 150;
  double vidaActual = 150;
  double direccionY = 1;
  final Random _rng = Random();

  JefeFinal() : super(size: Vector2(140, 140));

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox());
    position = Vector2(gameRef.size.x - 180, gameRef.size.y / 2);
    add(TimerComponent(period: 0.9, repeat: true, onTick: lanzarAtaque));
    
    try {
      final sprite = await gameRef.loadSprite('enemigo.png');
      add(SpriteComponent(sprite: sprite, size: size, paint: Paint()..colorFilter = const ColorFilter.mode(Colors.purple, BlendMode.modulate)));
    } catch (e) {
      add(RectangleComponent(size: size, paint: Paint()..color = Colors.purple));
    }
  }

  void lanzarAtaque() {
    double azar = _rng.nextDouble();
    Vector2 origen = position + Vector2(0, size.y / 2);
    if (azar < 0.7) {
      gameRef.add(BalaJefe(posicion: origen.clone(), angulo: -0.3));
      gameRef.add(BalaJefe(posicion: origen.clone(), angulo: 0));
      gameRef.add(BalaJefe(posicion: origen.clone(), angulo: 0.3));
    } else {
      gameRef.add(BalaJefe(posicion: origen, velocidad: 550, esRayo: true));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.y += 180 * dt * direccionY;
    if (position.y <= 0 || position.y >= gameRef.size.y - size.y) direccionY *= -1;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final barraAncho = size.x;
    const barraAlto = 10.0;
    final porcentajeVida = vidaActual / vidaMaxima;
    canvas.drawRect(Rect.fromLTWH(0, -20, barraAncho, barraAlto), Paint()..color = Colors.grey);
    canvas.drawRect(Rect.fromLTWH(0, -20, barraAncho * porcentajeVida, barraAlto), Paint()..color = Color.lerp(Colors.red, Colors.green, porcentajeVida)!);
  }

  void recibirDanio() {
    vidaActual--;
    if (vidaActual <= 0) {
      gameRef.puntos += 2000;
      gameRef.victoria();
      removeFromParent();
    }
  }
}

class BalaJefe extends PositionComponent with HasGameRef, CollisionCallbacks {
  late Paint _paint;
  final double angulo;
  final double velocidad;
  final bool esRayo;
  BalaJefe({required Vector2 posicion, this.angulo = 0, this.velocidad = 300, this.esRayo = false}) 
      : super(size: esRayo ? Vector2(45, 14) : Vector2(25, 10), position: posicion);
  @override
  Future<void> onLoad() async {
    add(RectangleHitbox());
    _paint = Paint()..color = esRayo ? Colors.white : Colors.purpleAccent;
  }
  @override
  void render(Canvas canvas) { canvas.drawRect(size.toRect(), _paint); }
  @override
  void update(double dt) {
    super.update(dt);
    position.x -= velocidad * dt;
    position.y += angulo * 150 * dt;
    if (position.x < -size.x) removeFromParent();
  }
}

class Bala extends PositionComponent with HasGameRef<SpaceImpactRemake>, CollisionCallbacks {
  final double angulo;
  Bala({required Vector2 posicionInicial, this.angulo = 0}) : super(size: Vector2(25, 8), position: posicionInicial);
  @override
  Future<void> onLoad() async { add(RectangleHitbox()); }
  @override
  void render(Canvas canvas) { canvas.drawRect(size.toRect(), Paint()..color = Colors.yellowAccent); }
  @override
  void update(double dt) {
    super.update(dt);
    position.x += 650 * dt;
    position.y += angulo * 400 * dt; 
    if (position.x > gameRef.size.x) removeFromParent();
  }
  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Enemigo) {
      gameRef.registrarBaja();
      other.removeFromParent();
      removeFromParent();
    } else if (other is JefeFinal) {
      other.recibirDanio();
      removeFromParent();
    }
  }
}

class Enemigo extends PositionComponent with HasGameRef<SpaceImpactRemake>, CollisionCallbacks {
  final double velocidad;
  Enemigo({required this.velocidad}) : super(size: Vector2(50, 40));
  @override
  Future<void> onLoad() async {
    add(RectangleHitbox());
    position = Vector2(gameRef.size.x, Random().nextDouble() * (gameRef.size.y - size.y));
    try {
      final sprite = await gameRef.loadSprite('enemigo.png');
      add(SpriteComponent(sprite: sprite, size: size));
    } catch (e) {
      add(PolygonComponent([Vector2(0, size.y / 2), Vector2(size.x, 0), Vector2(size.x, size.y)], paint: Paint()..color = Colors.orangeAccent));
    }
  }
  @override
  void update(double dt) {
    super.update(dt);
    position.x -= velocidad * dt;
    if (position.x < -size.x) removeFromParent();
  }
}

class EstrellaFondo extends CircleComponent with HasGameRef {
  EstrellaFondo() : super(radius: Random().nextDouble() * 1.5);
  @override
  Future<void> onLoad() async {
    paint = Paint()..color = Colors.white.withOpacity(Random().nextDouble());
    position = Vector2(Random().nextDouble() * gameRef.size.x, Random().nextDouble() * gameRef.size.y);
  }
  @override
  void update(double dt) {
    super.update(dt);
    position.x -= 45 * dt;
    if (position.x < 0) position.x = gameRef.size.x;
  }
}

class GameoverPanel extends PositionComponent with HasGameRef<SpaceImpactRemake>, TapCallbacks {
  final int puntos;
  final bool victoria;
  GameoverPanel({required this.puntos, required this.victoria});
  @override
  Future<void> onLoad() async {
    size = gameRef.size;
    add(RectangleComponent(size: size, paint: Paint()..color = Colors.black.withOpacity(0.8)));
    add(TextComponent(
      text: victoria ? '¡VICTORIA!\nHas salvado la Galaxia\n$puntos Puntos' : 'FIN DEL JUEGO\n$puntos Puntos\n\n(Toca para reiniciar)',
      anchor: Anchor.center, position: size / 2,
      textRenderer: TextPaint(style: TextStyle(color: victoria ? Colors.green : Colors.orange, fontSize: 24, fontWeight: FontWeight.bold)),
    ));
  }

  @override
  void onTapDown(TapDownEvent event) {
    gameRef.overlays.add('MenuInicio');
    removeFromParent();
  }
}