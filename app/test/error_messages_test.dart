import 'package:flutter_test/flutter_test.dart';
import 'package:zabmin/core/utils/error_messages.dart';

void main() {
  group('userFacingAgentError', () {
    test('maps protected_process to friendly message', () {
      expect(
        userFacingAgentError('protected_process'),
        'This process is protected and cannot be changed.',
      );
    });

    test('maps agent_process to friendly message', () {
      expect(
        userFacingAgentError('agent_process'),
        'Zabmin cannot stop or change its own agent process.',
      );
    });

    test('maps process_not_found to friendly message', () {
      expect(
        userFacingAgentError('process_not_found'),
        'The process is no longer running.',
      );
    });

    test('maps access_denied to friendly message', () {
      expect(
        userFacingAgentError('access_denied'),
        'You do not have permission to change this process.',
      );
    });

    test('maps rate_limited to friendly message', () {
      expect(
        userFacingAgentError('rate_limited'),
        'Too many requests. Please wait a moment.',
      );
    });

    test('maps invalid_pid to friendly message', () {
      expect(userFacingAgentError('invalid_pid'), 'Invalid process.');
    });

    test('maps invalid_priority to friendly message', () {
      expect(
        userFacingAgentError('invalid_priority'),
        'Invalid priority value.',
      );
    });

    test('maps internal_error to friendly message', () {
      expect(
        userFacingAgentError('internal_error'),
        'Something went wrong inside the agent.',
      );
    });

    test('maps Timeout to friendly message', () {
      expect(
        userFacingAgentError('Timeout'),
        'The operation timed out.',
      );
    });

    test('maps Disconnected to friendly message', () {
      expect(
        userFacingAgentError('Disconnected'),
        'Disconnected from agent.',
      );
    });

    test('returns raw string for unknown error', () {
      expect(
        userFacingAgentError('something_unexpected'),
        'something_unexpected',
      );
    });

    test('returns generic message for null', () {
      expect(userFacingAgentError(null), 'Unknown error.');
    });
  });
}
