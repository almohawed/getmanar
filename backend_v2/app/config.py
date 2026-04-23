from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    app_name: str = "School Schedule Solver V2"
    app_version: str = "2.0.0"
    cors_origins: str = "*"
    
    # ضع هنا JSON كامل لحساب الخدمة كسطر واحد في متغير بيئة
    firebase_credentials_json: str | None = None
    
    # إعدادات الجدولة
    max_solver_seconds: int = 30
    days_per_week: int = 5
    periods_per_day: int = 8  # تم تغييره من 7 إلى 8 لاستيعاب 40 حصة أسبوعياً
    
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

settings = Settings()
