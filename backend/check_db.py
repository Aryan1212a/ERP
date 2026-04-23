import sys
sys.path.insert(0, 'app')
from sqlalchemy import create_engine, text
engine = create_engine('sqlite:///school_erp.db')
with engine.connect() as conn:
    result = conn.execute(text('SELECT COUNT(*) FROM users'))
    print('Total users:', result.fetchone()[0])
    result = conn.execute(text('SELECT role, COUNT(*) FROM users GROUP BY role'))
    print('User counts by role:')
    for row in result:
        print(f'  {row[0]}: {row[1]}')