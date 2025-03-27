#
#
if [ -f users.htpasswd ]; then
  htpasswd -B users.htpasswd admin
else
  htpasswd -c -B users.htpasswd admin
fi

oc create secret generic htpass-secret --from-file=htpasswd=users.htpasswd -n openshift-config
oc apply -f htp-oauth.yaml
oc adm policy add-cluster-role-to-user cluster-admin admin
oc adm policy add-cluster-role-to-user cluster-admin molnars

MYBASE64STRING=$(echo core:$(printf "<<CHANGEME>>" | openssl passwd -6 --stdin) | base64 -w0)
cat << EOF > 99-set-core-passwd.yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: worker
  name: 99-worker-set-core-passwd
spec:
  config:
    ignition:
      version: 3.2.0
    storage:
      files:
      - contents:
          source: data:text/plain;charset=utf-8;base64,$MYBASE64STRING
        mode: 420
        overwrite: true
        path: /etc/core.passwd
    systemd:
      units:
      - name: set-core-passwd.service
        enabled: true
        contents: |
          [Unit]
          Description=Set 'core' user password for out-of-band login
          [Service]
          Type=oneshot
          ExecStart=/bin/sh -c 'chpasswd -e < /etc/core.passwd'
          [Install]
          WantedBy=multi-user.target
EOF

