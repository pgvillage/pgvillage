Role Name
=========

This role does 2 things:
1: It sets up the minio client for the minio user on the minio server
2: It creates buckets as requested. This uses local_action and requires python3-boto3.

Requirements
------------

Ansible host must have python3-boto3 package

Role Variables
--------------

minio_client_endpoint: endpoint info. Should be a map with the folowing keys:
- accessKey
- secretKey
- url


minio_client_buckets: a list of buckets that should be created.

Dependencies
------------

- atosatto.minio: Will setup minio on the server

Example Playbook
----------------

    - hosts: minio_server
      roles:
         - minio_client

License
-------

GNU GPL v3

Author Information
------------------


