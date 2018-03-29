INSTANCES="kube-1.foo.io kube-2.foo.io kube-3.foo.io"   # list of workers (no comma)
ETCD="172.16.0.10 172.16.0.11 172.16.0.12"
CERT="k8s-certs"  # folder for certs
REST=${CERT}"/rip"  # folder for CSR and JSON files

echo "${break}"
echo "generating ETCD server certs"

N=0
for instance in ${ETCD}; do
N=$[$N +1]
cat > ${REST}/server-etcd-0${N}.json <<EOF 
{
  "CN": "${instance}",
  "key": {
      "algo": "ecdsa",
      "size": 256
  },
  "hosts": [
      "${instance}",
      "etcd-0${N}.local"
  ],
  "names": [
    {
      "C": "${C}",
      "L": "${L}",
      "ST": "${ST}"
    }
  ]
}
EOF
cfssl gencert \
  -ca=${CERT}/ca.pem \
  -ca-key=${CERT}/ca-key.pem \
  -config=${REST}/ca-config.json \
  -profile=etcd-server \
  ${REST}/server-etcd-0${N}.json | cfssljson -bare ${CERT}/server-etcd-0${N}
done


echo "${break}"
echo "generating ETCD member certs"

N=0
for instance in ${ETCD}; do
N=$[$N +1]
cat > ${REST}/peer-etcd-0${N}.json <<EOF 
{
  "CN": "${instance}",
  "key": {
      "algo": "ecdsa",
      "size": 256
  },
  "hosts": [
      "${instance}",
      "peer-0${N}.local",
      "peer-0${N}"
  ],
  "names": [
    {
      "C": "${C}",
      "L": "${L}",
      "ST": "${ST}"
    }
  ]
}
EOF
cfssl gencert \
  -ca=${CERT}/ca.pem \
  -ca-key=${CERT}/ca-key.pem \
  -config=${REST}/ca-config.json \
  -profile=etcd-peer \
  ${REST}/peer-etcd-0${N}.json | cfssljson -bare ${CERT}/peer-etcd-0${N}
done


echo "${break}"
echo "generating ETCD client cert"

cat > ${REST}/etcd-client.json <<EOF 
{
    "CN": "client",
    "hosts": [""],
    "key": {
        "algo": "ecdsa",
        "size": 256
    }
}
EOF
cfssl gencert \
  -ca=${CERT}/ca.pem \
  -ca-key=${CERT}/ca-key.pem \
  -config=${REST}/ca-config.json \
  -profile=etcd-client \
  ${REST}/etcd-client.json | cfssljson -bare ${CERT}/etcd-client


echo "${break}"
echo "clean up *.csr / *.json stuff"

mv ${CERT}/*.csr ${REST}/ 