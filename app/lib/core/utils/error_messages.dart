String userFacingAgentError(String? error) {
  switch (error) {
    case 'protected_process':
      return 'This process is protected and cannot be changed.';
    case 'agent_process':
      return 'Zabmin cannot stop or change its own agent process.';
    case 'process_not_found':
      return 'The process is no longer running.';
    case 'access_denied':
      return 'You do not have permission to change this process.';
    case 'rate_limited':
      return 'Too many requests. Please wait a moment.';
    case 'invalid_pid':
      return 'Invalid process.';
    case 'invalid_priority':
      return 'Invalid priority value.';
    case 'internal_error':
      return 'Something went wrong inside the agent.';
    case 'Timeout':
      return 'The operation timed out.';
    case 'Disconnected':
      return 'Disconnected from agent.';
    default:
      return error ?? 'Unknown error.';
  }
}
