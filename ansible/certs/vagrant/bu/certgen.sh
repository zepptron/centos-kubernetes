### define vars

MASTERS="172.16.0.10"  # comma separated list of masternodes
API="https://172.16.0.10:6443"  # add Loadbalancer here
INSTANCES="kube-1.foo.io kube-2.foo.io kube-3.foo.io"   # list of workers (no comma)
SVC_CIDR="10.10.0.1"

# certstuff
EXPIRE="8760h"
C="DE"
L="munich"
O="Kubernetes"
OU="muc"
ST="bavaria"

# folders
CERT="k8s-certs"  # folder for certs
REST=${CERT}"/rip"  # folder for CSR and JSON files

break="================================="


echo "${break}"
echo "adding folders if not present"

mkdir -p ${REST}  

echo "${break}"
echo "generate CA certs"

cat > ${REST}/ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "${EXPIRE}"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "${EXPIRE}"
      }
    }
  }
}
EOF

cat > ${REST}/ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "${C}",
      "L": "${L}",
      "O": "${O}",
      "OU": "${OU}",
      "ST": "${ST}"
    }
  ]
}
EOF

cfssl gencert -initca ${REST}/ca-csr.json | cfssljson -bare ${CERT}/ca


echo "${break}"
echo "generate cert for admin access (kubectl)"

cat > ${REST}/admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "${C}",
      "L": "${L}",
      "O": "system:masters",
      "OU": "${OU}",
      "ST": "${ST}"
    }
  ]
}
EOF

cfssl gencert \
  -ca=${CERT}/ca.pem \
  -ca-key=${CERT}/ca-key.pem \
  -config=${REST}/ca-config.json \
  -profile=kubernetes \
  ${REST}/admin-csr.json | cfssljson -bare ${CERT}/admin


echo "${break}"
echo "generate cert for useraccess (ext. kubectl)"

cat > ${REST}/user-csr.json <<EOF
{
  "CN": "dulli",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "${C}",
      "L": "${L}",
      "O": "system:dulli",
      "OU": "${OU}",
      "ST": "${ST}"
    }
  ]
}
EOF

cfssl gencert \
  -ca=${CERT}/ca.pem \
  -ca-key=${CERT}/ca-key.pem \
  -config=${REST}/ca-config.json \
  -profile=kubernetes \
  ${REST}/user-csr.json | cfssljson -bare ${CERT}/user


echo "${break}"
echo "generate certs for worker nodes"

N=10
for instance in ${INSTANCES}; do
N=$[$N +1]
cat > ${REST}/${instance}-csr.json <<EOF
{
  "CN": "system:node:${instance}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "${C}",
      "L": "${L}",
      "O": "system:nodes",
      "OU": "${OU}",
      "ST": "${ST}"
    }
  ]
}
EOF
  
cfssl gencert \
  -ca=${CERT}/ca.pem \
  -ca-key=${CERT}/ca-key.pem \
  -config=${REST}/ca-config.json \
  -hostname=${instance},172.16.0.${N} \
  -profile=kubernetes \
  ${REST}/${instance}-csr.json | cfssljson -bare ${CERT}/${instance}
done


echo "${break}"
echo "generate kube-proxy cert"

cat > ${REST}/kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "${C}",
      "L": "${L}",
      "O": "system:node-proxier",
      "OU": "${OU}",
      "ST": "${ST}"
    }
  ]
}
EOF

cfssl gencert \
  -ca=${CERT}/ca.pem \
  -ca-key=${CERT}/ca-key.pem \
  -config=${REST}/ca-config.json \
  -profile=kubernetes \
  ${REST}/kube-proxy-csr.json | cfssljson -bare ${CERT}/kube-proxy


echo "${break}"
echo "generating kubernetes API cert (adjust when deployed as HA!)"

cat > ${REST}/kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "${C}",
      "L": "${L}",
      "O": "${O}",
      "OU": "${OU}",
      "ST": "${ST}"
    }
  ]
}
EOF

cfssl gencert \
  -ca=${CERT}/ca.pem \
  -ca-key=${CERT}/ca-key.pem \
  -config=${REST}/ca-config.json \
  -hostname=${SVC_CIDR},${MASTERS},127.0.0.1,kubernetes.default \
  -profile=kubernetes \
  ${REST}/kubernetes-csr.json | cfssljson -bare ${CERT}/kubernetes

### 10.10.0.1 => service cidr!
### 172.16.0.1* = API Servers! If deployed in HA, add them!


echo "${break}"
echo "generating .kubeconfig for nodes"

for instance in ${INSTANCES}; do
  kubectl config set-cluster kubernetes \
    --certificate-authority=${CERT}/ca.pem \
    --embed-certs=true \
    --server=${API} \
    --kubeconfig=${CERT}/${instance}.kubeconfig

  kubectl config set-credentials system:node:${instance} \
    --client-certificate=${CERT}/${instance}.pem \
    --client-key=${CERT}/${instance}-key.pem \
    --embed-certs=true \
    --kubeconfig=${CERT}/${instance}.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes \
    --user=system:node:${instance} \
    --kubeconfig=${CERT}/${instance}.kubeconfig

  kubectl config use-context default --kubeconfig=${CERT}/${instance}.kubeconfig
done


echo "${break}"
echo "generating .kubeconfig for kube-proxy"

kubectl config set-cluster kubernetes \
  --certificate-authority=${CERT}/ca.pem \
  --embed-certs=true \
  --server=${API} \
  --kubeconfig=${CERT}/kube-proxy.kubeconfig

kubectl config set-credentials kube-proxy \
  --client-certificate=${CERT}/kube-proxy.pem \
  --client-key=${CERT}/kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=${CERT}/kube-proxy.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes \
  --user=kube-proxy \
  --kubeconfig=${CERT}/kube-proxy.kubeconfig

kubectl config use-context default --kubeconfig=${CERT}/kube-proxy.kubeconfig


echo "${break}"
echo "KUBECTL config for external access"

kubectl config set-cluster dummy \
  --certificate-authority=${CERT}/ca.pem \
  --embed-certs=true \
  --server=${API}

kubectl config set-credentials dulli \
  --client-certificate=${CERT}/user.pem \
  --client-key=${CERT}/user-key.pem

kubectl config set-context dummy \
  --cluster=dummy \
  --user=dulli


echo "${break}"
echo "clean up *.csr / *.json stuff"

mv ${CERT}/*.csr ${REST}/ 
