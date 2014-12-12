# Ceph Rados Gateway

Run your own distributed s3 storage in docker.

## Ceph cluster creation

Let's assume that you want to test ceph on single machine.
Our lan ip is `192.168.0.7` and hostname is `callisto`.
To keep configs in sync we will bind-mount them from host
dir `/media/backups/ceph/etc`. We will use `s3.rgw.ceph`
as root domain for s3 communication.

Run monitor node:

```
docker run -d --net=host -e MON_IP=192.168.0.7 -e MON_NAME=callisto \
  -v /media/backups/ceph/etc:/etc/ceph --name=ceph.mon0 ulexus/ceph-mon
```

To proceed, we need to enter `ceph.mon0` (docker-enter or nsenter) and
allocate 3 osd nodes for future use:

```
ceph osd create
ceph osd create
ceph osd create
```

Run 3 osd nodes with ids 0, 1 and 2:

```
docker run -d -e OSD_ID=0 -v /media/backups/ceph/etc:/etc/ceph \
  -v /media/backups/ceph/osd.0:/var/lib/ceph/osd/ceph-0 --name ceph.osd0 ulexus/ceph-osd

docker run -d -e OSD_ID=1 -v /media/backups/ceph/etc:/etc/ceph \
  -v /media/backups/ceph/osd.1:/var/lib/ceph/osd/ceph-1 --name ceph.osd1 ulexus/ceph-osd

docker run -d -e OSD_ID=2 -v /media/backups/ceph/etc:/etc/ceph \
  -v /media/backups/ceph/osd.2:/var/lib/ceph/osd/ceph-2 --name ceph.osd2 ulexus/ceph-osd
```

In `ceph.mon0` run following commands:

```
ceph-authtool --create-keyring /etc/ceph/ceph.client.radosgw.keyring
chmod +r /etc/ceph/ceph.client.radosgw.keyring
ceph-authtool /etc/ceph/ceph.client.radosgw.keyring -n client.radosgw.gateway --gen-key
ceph-authtool -n client.radosgw.gateway --cap osd 'allow rwx' --cap mon 'allow rwx' /etc/ceph/ceph.client.radosgw.keyring
ceph -k /etc/ceph/ceph.client.admin.keyring auth add client.radosgw.gateway -i /etc/ceph/ceph.client.radosgw.keyring
```

Add following to your `/etc/ceph/ceph.conf`:

```
[client.radosgw.gateway]
keyring = /etc/ceph/ceph.client.radosgw.keyring
rgw socket path = /var/run/ceph/ceph.radosgw.gateway.fastcgi.sock
log file = /var/log/ceph/client.radosgw.gateway.log
rgw print continue = false
rgw_dns_name = s3.rgw.ceph
```

Enter `ceph.mon0` once again to create user:

```
apt-get update
apt-get install radosgw
radosgw-admin --name client.radosgw.gateway user create --uid alice --display-name "Alice"
```

You will get keys to use with s3 in the output. Note that in json output
some chars could be escaped, you don't need extra `\` in your s3 client settings.

Now let's run rados gateway at last:

```
docker run -d -p 192.168.0.7:80:80 -v /media/backups/ceph/etc:/etc/ceph \
  --name ceph.radosgw0 bobrik/radosgw
```

## Using s3 storage

Usually s3 clients address buckets in format `<bucket>.<s3_host>`.
To create and use buckets we need to point `<s3_host>` to `192.168.0.7`
with all subdomains. If you don't have dns, just add following to `/etc/hosts`
to use `s3.rgw.ceph` as `<s3_host>`:

```
192.168.0.7 s3.rgw.ceph whatever.s3.rgw.ceph
```

This will also allow you to use bucket `whatever`. If you need more buckets,
just add them to `/etc/hosts`.
