import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from agent import (
    _SESSION_TOKEN,
    extract_token_from_request_path,
    token_is_valid,
)


class TestExtractTokenFromRequestPath:
    def test_extracts_token(self):
        assert extract_token_from_request_path("/?token=abc") == "abc"

    def test_no_token_returns_none(self):
        assert extract_token_from_request_path("/") is None

    def test_other_param_returns_none(self):
        assert extract_token_from_request_path("/?other=1") is None

    def test_token_with_special_chars(self):
        token = "abc123-xyz_ABC"
        assert extract_token_from_request_path(f"/?token={token}") == token

    def test_multiple_params_extracts_token(self):
        assert extract_token_from_request_path("/?foo=1&token=secret&bar=2") == "secret"


class TestTokenIsValid:
    def test_rejects_none(self):
        assert token_is_valid(None) is False

    def test_rejects_wrong_token(self):
        assert token_is_valid("wrongtoken") is False

    def test_rejects_empty_string(self):
        assert token_is_valid("") is False

    def test_accepts_correct_token(self):
        assert token_is_valid(_SESSION_TOKEN) is True

    def test_token_must_match_exactly(self):
        assert token_is_valid(_SESSION_TOKEN.upper()) is False
