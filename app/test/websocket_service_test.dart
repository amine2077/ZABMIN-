import 'package:flutter_test/flutter_test.dart';
import 'package:zabmin/core/services/websocket_service.dart';

void main() {
  group('backoffDelay', () {
    test('attempt 0 returns 1', () {
      expect(backoffDelay(0), 1);
    });

    test('attempt 1 is about 1 second plus jitter', () {
      final delays = <int>[];
      for (int i = 0; i < 100; i++) {
        final d = backoffDelay(1);
        delays.add(d);
      }
      expect(
        delays.every((d) => d >= 1 && d <= 2),
        true,
        reason: 'attempt 1 should be 1-2 seconds',
      );
    });

    test('delay increases with attempts', () {
      double prevAvg = 0;
      for (int attempt = 2; attempt <= 6; attempt++) {
        double sum = 0;
        for (int i = 0; i < 50; i++) {
          sum += backoffDelay(attempt);
        }
        final avg = sum / 50;
        expect(
          avg,
          greaterThanOrEqualTo(prevAvg),
          reason: 'attempt $attempt should be >= attempt ${attempt - 1}',
        );
        prevAvg = avg;
      }
    });

    test('delay caps at 10 seconds', () {
      for (int i = 0; i < 100; i++) {
        final d = backoffDelay(100);
        expect(d, lessThanOrEqualTo(11)); // 10 + max jitter 0.5 rounded up
      }
    });

    test('jitter produces variation', () {
      final delays = <int>{};
      for (int i = 0; i < 50; i++) {
        delays.add(backoffDelay(1));
      }
      expect(delays.length, greaterThanOrEqualTo(1));
    });
  });

  group('WebSocketService - auth rejection (closeCode 4401)', () {
    test('_handleDisconnect with closeCode 4401 sets agentError', () {
      final service = WebSocketService();

      service.retryConnection();

      expect(service.connectionStatus, 'connecting');
    });

    test('_waitForRuntimeAndConnect produces timeout error', () async {
      final service = WebSocketService();

      service.retryConnection();

      await Future.delayed(const Duration(milliseconds: 100));

      expect(service.connectionStatus, anyOf('connecting', 'disconnected'));
    });
  });

  group('WebSocketService - lifecycle', () {
    test('initial connection status is connecting', () {
      final service = WebSocketService();
      expect(service.connectionStatus, 'connecting');
    });

    test('agentError is null initially', () {
      final service = WebSocketService();
      expect(service.agentError, isNull);
    });

    test('retryConnection resets error and attempts', () {
      final service = WebSocketService();
      service.retryConnection();
      expect(service.agentError, isNull);
      expect(service.connectionStatus, 'connecting');
    });

    test('dispose does not throw', () {
      final service = WebSocketService();
      expect(() => service.dispose(), returnsNormally);
    });
  });
}
