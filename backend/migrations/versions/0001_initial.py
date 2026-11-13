"""Initial private storage, vector extension and forced RLS."""
from alembic import op
from app.models.tables import Base

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    op.execute("CREATE EXTENSION IF NOT EXISTS vector")
    Base.metadata.create_all(op.get_bind())
    op.execute("CREATE UNIQUE INDEX preference_identity ON preferences(tenant_id, user_id)")
    for name in Base.metadata.tables:
        op.execute(f'ALTER TABLE {name} ENABLE ROW LEVEL SECURITY')
        op.execute(f'ALTER TABLE {name} FORCE ROW LEVEL SECURITY')
        owner = "tenant_id = current_setting('app.tenant_id', true)"
        if name != "tenant_budgets":
            owner += " AND user_id = current_setting('app.user_id', true)"
        op.execute(f"CREATE POLICY private_identity ON {name} USING ({owner}) WITH CHECK ({owner})")


def downgrade():
    Base.metadata.drop_all(op.get_bind())
