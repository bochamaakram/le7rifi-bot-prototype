from alembic import context
from sqlalchemy import create_engine
from app.config.settings import get_settings
from app.models.tables import Base

config = context.config
engine = create_engine(get_settings().database_url)
with engine.connect() as connection:
    context.configure(connection=connection, target_metadata=Base.metadata)
    with context.begin_transaction():
        context.run_migrations()
