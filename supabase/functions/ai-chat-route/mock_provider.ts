import type { AiGatewayErrorCode, GatewayRequest } from "./contracts.ts";

export const mockProviderText =
  "This is a FitLog AI mock reply. Your text message was received.";

export class MockProviderError extends Error {
  readonly code: AiGatewayErrorCode;

  constructor(code: AiGatewayErrorCode) {
    super(code);
    this.code = code;
  }
}

export function runMockProvider(request: GatewayRequest): string {
  if (request.messageText.includes("[mock_timeout]")) {
    throw new MockProviderError("gateway_timeout");
  }
  if (request.messageText.includes("[mock_failure]")) {
    throw new MockProviderError("provider_failure");
  }
  return mockProviderText;
}
