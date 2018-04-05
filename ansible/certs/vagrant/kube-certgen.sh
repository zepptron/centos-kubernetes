### define vars

MASTERS="172.16.0.10"  # comma separated list of masternodes
API="https://172.16.0.10:6443"  # add Loadbalancer here
INSTANCES="kube-1.foo.io kube-2.foo.io kube-3.foo.io"   # list of workers (no comma)
ETCD="172.16.0.10 172.16.0.11 172.16.0.12"
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

# keygen
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

BREAK="================================="


#####################################################################################  
#################################### generate CA #################################### 
#####################################################################################

echo "${BREAK}"
echo "adding folders if not present"

mkdir -p ${REST}  

echo "${BREAK}"
echo "generate CA certs"

cat > ${REST}/ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "${EXPIRE}"
    },
    "profiles": {
      "kubernetes": {
        "expiry": "${EXPIRE}",
        "usages": [
            "signing", 
            "key encipherment", 
            "server auth", 
            "client auth"
        ]
      },
      "etcd-server": {
        "expiry": "${EXPIRE}",
        "usages": [
            "signing",
            "key encipherment",
            "server auth"
        ]
      },
      "etcd-client": {
        "expiry": "${EXPIRE}",
        "usages": [
            "signing",
            "key encipherment",
            "client auth"
        ]
      },
      "etcd-peer": {
        "expiry": "${EXPIRE}",
        "usages": [
            "signing",
            "key encipherment",
            "server auth",
            "client auth"
        ]
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


#####################################################################################  
############################### generate kubectl certs ############################## 
#####################################################################################

echo "${BREAK}"
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

echo "${BREAK}"
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


#####################################################################################  
############################## generate kube corecerts ############################## 
#####################################################################################


echo "${BREAK}"
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

echo "${BREAK}"
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


echo "${BREAK}"
echo "generate kube-scheduler cert"

cat > ${REST}/kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
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
  ${REST}/kube-scheduler-csr.json | cfssljson -bare ${CERT}/kube-scheduler

echo "${BREAK}"
echo "generate kube-controller-manager cert"

cat > ${REST}/kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
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
  ${REST}/kube-controller-manager-csr.json | cfssljson -bare ${CERT}/kube-controller-manager

echo "${BREAK}"
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


#####################################################################################  
################################ generate kubeconfig ################################ 
#####################################################################################

echo "${BREAK}"
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

echo "${BREAK}"
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

echo "${BREAK}"
echo "generating .kubeconfig for kube-scheduler"

kubectl config set-cluster kubernetes \
  --certificate-authority=${CERT}/ca.pem \
  --embed-certs=true \
  --server=${API} \
  --kubeconfig=${CERT}/kube-scheduler.kubeconfig

kubectl config set-credentials kube-scheduler \
  --client-certificate=${CERT}/kube-scheduler.pem \
  --client-key=${CERT}/kube-scheduler-key.pem \
  --embed-certs=true \
  --kubeconfig=${CERT}/kube-scheduler.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes \
  --user=kube-scheduler \
  --kubeconfig=${CERT}/kube-scheduler.kubeconfig

kubectl config use-context default --kubeconfig=${CERT}/kube-scheduler.kubeconfig

echo "${BREAK}"
echo "generating .kubeconfig for kube-controller-manager"

kubectl config set-cluster kubernetes \
  --certificate-authority=${CERT}/ca.pem \
  --embed-certs=true \
  --server=${API} \
  --kubeconfig=${CERT}/kube-controller-manager.kubeconfig

kubectl config set-credentials kube-controller-manager \
  --client-certificate=${CERT}/kube-controller-manager.pem \
  --client-key=${CERT}/kube-controller-manager-key.pem \
  --embed-certs=true \
  --kubeconfig=${CERT}/kube-controller-manager.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes \
  --user=kube-controller-manager \
  --kubeconfig=${CERT}/kube-controller-manager.kubeconfig

kubectl config use-context default --kubeconfig=${CERT}/kube-controller-manager.kubeconfig


#####################################################################################  
############################## external kubectl access ############################## 
#####################################################################################

echo "${BREAK}"
echo "KUBECTL config for external USER access [restricted]"

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

echo "${BREAK}"
echo "KUBECTL config for external ADMIN access [chef]"

kubectl config set-cluster vagrant \
  --certificate-authority=${CERT}/ca.pem \
  --embed-certs=true \
  --server=${API}

kubectl config set-credentials admin \
  --client-certificate=${CERT}/admin.pem \
  --client-key=${CERT}/admin-key.pem

kubectl config set-context vagrant \
  --cluster=vagrant \
  --user=admin


#####################################################################################  
################################ generate ETCD certs ################################ 
#####################################################################################

echo "${BREAK}"
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

echo "${BREAK}"
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

echo "${BREAK}"
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


#####################################################################################  
################################# kubernetes secret ################################# 
#####################################################################################

echo "${BREAK}"
echo "Generate base64 encoded etcd secret"

key="$(base64 < ${CERT}/etcd-client-key.pem)";
cert="$(base64 < ${CERT}/etcd-client.pem)";
ca="$(base64 < ${CERT}/ca.pem)";

cat > ${CERT}/etcd-secret.yml <<EOF
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: calico-etcd-secrets
  namespace: kube-system
data: 
  etcd-key: "${key}"
  etcd-cert: "${cert}"
  etcd-ca: "${ca}"
EOF

echo "done."


#####################################################################################  
################################### encryptconfig ################################### 
#####################################################################################

echo "${BREAK}"
echo "generating encryptconfig"

cat > ${CERT}/encryption-config.yml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF

echo "done."


#####################################################################################  
###################################### cleanup ###################################### 
#####################################################################################

echo "${BREAK}"
echo "clean up *.csr / *.json stuff"

mv ${CERT}/*.csr ${REST}/ 

echo "done."
echo "${BREAK}"