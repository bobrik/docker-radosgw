# Ceph Rados Gateway

Run your own distributed s3 storage in docker.

## Ceph cluster creation

Let's assume that you want to test ceph on a single machine.
Our lan ip is `192.168.0.7` and hostname is `callisto`.
To keep configs in sync we will bind-mount them from host
dir `/media/backups/ceph/etc`. We will use `s3.rgw.ceph`
as root domain for s3 communication.

Run monitor node:

```
docker run -d --net=host -e MON_IP=192.168.0.7 -e MON_NAME=callisto \
  -v /media/backups/ceph/etc:/etc/ceph --name=ceph.mon0 ceph/mon
```

To proceed, we need to enter `ceph.mon0` (docker-enter or nsenter) and
allocate 3 osd nodes for future use:

```
docker exec ceph.mon0 ceph osd create
docker exec ceph.mon0 ceph osd create
docker exec ceph.mon0 ceph osd create
```

Run 3 osd nodes with ids 0, 1 and 2:

```
docker run -d -e OSD_ID=0 -v /media/backups/ceph/etc:/etc/ceph \
  -v /media/backups/ceph/osd.0:/var/lib/ceph/osd/ceph-0 --name ceph.osd0 ceph/osd

docker run -d -e OSD_ID=1 -v /media/backups/ceph/etc:/etc/ceph \
  -v /media/backups/ceph/osd.1:/var/lib/ceph/osd/ceph-1 --name ceph.osd1 ceph/osd

docker run -d -e OSD_ID=2 -v /media/backups/ceph/etc:/etc/ceph \
  -v /media/backups/ceph/osd.2:/var/lib/ceph/osd/ceph-2 --name ceph.osd2 ceph/osd
```

Enable radosgw auth in `ceph.mon0`:

```
docker exec ceph.mon0 ceph-authtool --create-keyring /etc/ceph/keyring.radosgw.gateway
docker exec ceph.mon0 chmod +r /etc/ceph/keyring.radosgw.gateway
docker exec ceph.mon0 ceph-authtool /etc/ceph/keyring.radosgw.gateway -n client.radosgw.gateway --gen-key
docker exec ceph.mon0 ceph-authtool -n client.radosgw.gateway --cap osd 'allow rwx' --cap mon 'allow rw' /etc/ceph/keyring.radosgw.gateway
docker exec ceph.mon0 ceph -k /etc/ceph/ceph.client.admin.keyring auth add client.radosgw.gateway -i /etc/ceph/keyring.radosgw.gateway
```

Add following to your `/etc/ceph/ceph.conf`:

```
[client.radosgw.gateway]
keyring = /etc/ceph/keyring.radosgw.gateway
rgw socket path = /var/run/ceph/ceph.radosgw.gateway.fastcgi.sock
log file = /var/log/ceph/client.radosgw.gateway.log
rgw print continue = false
rgw_dns_name = s3.rgw.ceph
```

Create user to access s3 gateway:

```
docker run --rm -it -v /media/backups/ceph/etc:/etc/ceph --entrypoint radosgw-admin ceph/radosgw \
    --name client.radosgw.gateway user create --uid alice --display-name "Alice"
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

## Release history

* `bobrik/radosgw:1.0` first versioned release.
