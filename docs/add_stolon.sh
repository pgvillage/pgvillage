[root@vmsscluster1000009 etcd]# diff *
17,18c17,18
<ETCD_INITIAL_CLUSTER="vmsscluster1000001.internal.cloudapp.net=http://10.0.1.6:2380,vmsscluster1000002.internal.cloudapp.net=http://10.0.1.7:2380,vmsscluster1000004.internal.cloudapp.net=http://10.0.1.9:2380,vmsscluster1000008.internal.cloudapp.net=http://10.0.1.11:2380,vmsscluster1000009.internal.cloudapp.net=http://10.0.1.5:2380"
<ETCD_INITIAL_CLUSTER_STATE="new"
---
>ETCD_INITIAL_CLUSTER="vmsscluster1000001.internal.cloudapp.net=http://10.0.1.6:2380,vmsscluster1000002.internal.cloudapp.net=http://10.0.1.7:2380,vmsscluster1000004.internal.cloudapp.net=http://10.0.1.9:2380,vmsscluster1000008.internal.cloudapp.net=http://10.0.1.11:2380"
>ETCD_INITIAL_CLUSTER_STATE="existing"
