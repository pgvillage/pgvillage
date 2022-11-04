#!/usr/bin/env python3
import os
import psycopg2
import time
cn=None
last = None
SLEEPTIME=float(os.environ.get('AVCHECKER_SLEEPTIME', '5'))
while True:
    try:
        time.sleep(SLEEPTIME)
        if not cn:
            cn = psycopg2.connect('')
            cur = cn.cursor()
            cur.execute('select count(*) from pg_class where relname = %s and relnamespace in (select oid from pg_namespace where nspname=%s) ', ('avchecker', 'public'))
            if next(cur)[0] == 0:
                print('Creating table')
                cur.execute('create table public.avchecker(last timestamp)')
                cur.execute('insert into public.avchecker values(now())')
        cur.execute('BEGIN')
        cur.execute('update public.avchecker set last = now()')
        cur.execute('COMMIT')
        cur.execute('select last from public.avchecker')
        row=next(cur)
        new = row[0]
        if last:
            delta = new-last
            if delta.total_seconds() >= (SLEEPTIME*1.5):
                print(delta, flush=True)
        last = new
    except (psycopg2.InternalError, psycopg2.OperationalError, psycopg2.DatabaseError) as err:
        print(str(err).split('\n')[0])
        cn = None
