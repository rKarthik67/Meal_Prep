from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str = "postgresql+psycopg://localhost:5432/meal_prep"

    # "dev"      -> accepts tokens of the form "dev:<phone>" (no Firebase needed)
    # "firebase" -> verifies Firebase ID tokens (phone OTP login from the app)
    auth_mode: str = "dev"
    # Path to the Firebase service-account JSON (only needed when auth_mode=firebase)
    firebase_credentials: str | None = None

    cors_origins: list[str] = ["*"]

    # ---- AI ----
    # Default provider: azure | anthropic | ollama | mock  (mock = offline demo, no keys needed)
    ai_provider: str = "mock"
    ai_max_steps: int = 6

    azure_openai_endpoint: str | None = None  # https://<resource>.openai.azure.com
    azure_openai_api_key: str | None = None
    azure_openai_deployment: str | None = None  # your deployment name
    azure_openai_api_version: str = "2025-04-01-preview"

    anthropic_api_key: str | None = None
    anthropic_model: str = "claude-sonnet-5-5"

    ollama_base_url: str = "http://localhost:11434"
    ollama_model: str = "llama3.1:8b"  # any tool-calling model you've pulled

    # Pricing knobs (INR)
    extra_guest_fee: int = 50  # per guest above 4
    platform_fee_pct: int = 10


@lru_cache
def get_settings() -> Settings:
    return Settings()
