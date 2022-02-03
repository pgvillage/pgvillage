#!/usr/bin/env python
import psycopg2
import time
cn=None
last = None
while True:
    try:
        time.sleep(.1)
        if not cn:
            cn = psycopg2.connect('')
            cur = cn.cursor()
            cur.execute('select count(*) from pg_class where relname = %s and relnamespace in (select oid from pg_namespace where nspname=%s) ', ('last', 'public'))
            if next(cur)[0] == 0:
                print('Creating table')
                cur.execute('create table public.last(t timestamp)')
                cur.execute('insert into public.last values(now())')
        cur.execute('BEGIN')
        cur.execute('update public.last set t = now()')
        cur.execute('COMMIT')
        cur.execute('select t from public.last')
        row=next(cur)
        new = row[0]
        if last:
            delta = new-last
            if delta.total_seconds() >= .15:
                print(delta, flush=True)
        last = new
    except (psycopg2.InternalError, psycopg2.OperationalError, psycopg2.DatabaseError) as err:
        print(str(err).split('\n')[0])
        cn = None

