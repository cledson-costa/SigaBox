

# Projeto SigaBox

Este repositório busca demonstrar as instruções para execução dos procedimentos solicitados da atividade solicitada

## Sumário

- [Pré-requisitos](#pré-requisitos)
- [Construção da Máquina Operacional](#construção-da-máquina-operacional)
- [Execução Docker do Serviço](#execução-docker-do-serviço)
- [Instalação e controle via Kubernetes](#instalação-e-controle-via-kubernetes)
- [Criação do pod Tomcat para uso](#criação-do-pod-tomcat-para-uso)
- [Preparação do Node Exporter e Jolokia Exporter](#preparação-do-node-exporter-e-jolokia-exporter)
- [Instalação e Configuração do Prometheus](#instalação-e-configuração-do-prometheus)
- [Instalação e Configuração do Grafana](#instalação-e-configuração-do-grafana)
- [Conclusões](#conclusões)

## Pré-requisitos

1. Conta AWS
2. Máquina EC2 para operação de serviço

---

## Construção da Máquina Operacional

Para executar a criação do servidor será necessário criar uma máquina EC2 para controle dos serviços internos do sistema.

### Passos:

1. Criar uma infraestrutura básica na AWS com as seguintes propriedades
    - OS: ubuntu 22.04
    - região: us-east-1 (mas pode ser qualquer outra)
    - Tipo de Instância: t3.small (requisito mínimo para kubernetes: 2vCPU's e 2 Gb de RAM)
    - Armazenamento: 15 Gb
    - Criar par de chaves para uso
    - Grupo de Segurança: Liberação das portas ssh (22) e TCP (8080, 30080, 30030, 30090)
    - Criar e vincular IP elástico para facilitar conexões futuras
    
2. Em seguida é necessário adicionar uma pasta para execução do projeto, a mesma pode se ter o próprio nome do repositório ou fazer download do repositório presente

   
---

## Execução Docker do Serviço

### Montagem do ambiente

1. Pra instalação do Docker segue-se a documentação do site https://docs.docker.com/engine/install/ubuntu/ onde se segue instruções para preparação do repositório `apt`. Feita a preparação basta instalar os plugins necessários. Feita essa preparação o comando para instalação é feita com os seguintes comandos:

    ```
    sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    ```
    
    Feita a instalação desse sistema o docker estará pronto para criação de imagens e containers
    
    Dentro do arquivo `Dockerfile` configurado está a versão do Apache Tomcat 10.1.40, Jenkins 2.504.1 e Jolokia 2.2.9. A aplicação para o Jenkins e Jolokia será feito dentro da pasta webapps por serem `.WAR`

2. Para dar inicio é feito o procedimento de criação de imagem através do comando `docker build` que irá disponibilizar uma imagem local através do comando:

    ```
    docker build -t tomcat:1.0 .
    ```

3. Após criação da imagem é necessário executar o comando do docker para rodar o container da imagem criada através do comando:

    ```
    docker run -d -p 8080:8080 --name tomcat tomcat:1.0
    ```

4. Com isso o sistema com Jenkins e Jolokia ficam acessíveis no endereço do host `/jolokia` e `/jenkins`

    ```
    http://<endereço IP elástico>:8080/jolokia
    http://<endereço IP elástico>:8080/jenkins
    ```

> [!CAUTION]
> Por motivos do uso da ferramenta Kubeadm essa imagem criada deve ser levada para repositório online como DockerHub e assim utilizada para deploy no Kubernetes já que é dificultada a leitura de imagens locais pelo Kubeadm

---

## Instalação e controle via Kubernetes


A instalação do Kubernetes estará usando o Kubeadm, por isso é necessário seguir uma ordem de instalação para sua execução, assim como aderir a um CNI (Container Network Interface) para controle de rede interna.

1. É necessário fazer preparação na máquina com os seguintes requisitos.

    Desabilitar SWAP Para evitar criação de nós se não houver memória disponível:
    
    ```
    swapoff -a
    sed -i '/ swap / s/^/#/' /etc/fstab
    ```
    
    Ativar os módulos `overlay` e `br_netfilter` e configurá-los:
    
    ```
    sudo modprobe overlay
    sudo modprobe br_netfilter
    
    #Configuração dos módulos
    cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
    overlay
    br_netfilter
    EOF
    
    cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
    net.bridge.bridge-nf-call-iptables  = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    net.ipv4.ip_forward                 = 1
    EOF
    
    sudo sysctl --system
    ```
       
    E configurar o `containerd` já instalado do passo do docker e seus runtimes:
    
    ```
    sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
    
    # Cria configuração do containerd
    sudo mkdir -p /etc/containerd
    sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
    sudo systemctl restart containerd
    sudo systemctl enable containerd
    ```

2. Após a preparação podemos instalar o `kubeadm`, `kubelet` e o `kubectl`:

   ```
   # Adição da chave do repositório
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes.gpg
    
    # Adiciona repositório Kubernetes
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | \
      sudo tee /etc/apt/sources.list.d/kubernetes.list
    
    # Instalação
    sudo apt update
    sudo apt install -y kubelet kubeadm kubectl
    sudo apt-mark hold kubelet kubeadm kubectl
   ```
   
3. Para iniciar o serviço iremos dar início configurando também o Pod CIDR para manter a rede que atuará o serviço do kubeadm. O CIDR usado será 10.244.0.0/16

    ```
    kubeadm init --pod-network-cidr=10.244.0.0/16
    ```
   
5. Como requisito do sistema do Kubeadm é necessário adicionar um CNI (Container Network Interface) que no nosso caso será usado o flannel.

   ```
   kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
   ```
   
6. Assim o Kubeadm está em funcionamento e pronto para recebimento dos manifestos.


## Criação do pod Tomcat para uso

1. Usando o arquivo `tomcat-deploy` onde é montado uma versão deployment do tomcat é passada a imagem já criada anteriormente, mas dessa vez resgatada dentro do dockerhub. Além disso é criado um service ClusterIP dentro do próprio pod para referenciamento futuro além do NodePort na porta `30080` para acesso externo dos serviços Jolokia e Jenkins.

2. Para executar o serviço no kuberentes é seguido o comando:

   ```
   kubectl apply -f tomcat-deploy.yaml
   kubectl apply -f tomcat-service.yaml
   ```

## Preparação do Node Exporter e Jolokia Exporter

1. Para configuração do Prometheus será preparado o caminho da leitura dos sistemas do node kubernetes e do jolokia endpoint

2. Para preparação do node será usado um `DaemonSet` do node onde será aplicado para leitura de cada nó (nesse caso o nó individual do control plane). A confiuração visa estabelecer a leitura do nó e expondo para o prometheus a porta `9100`. Podemos então aplicar o manifesto com:

   ```
    kubectl apply -f node-exporter-daemon.yaml
   ```
3. Já para criação do Jolokia exporter foi usada solução `SideCar` do Kubernetes onde dentro do próprio pod tomcat será adicionado um container usando a imagem de um projeto já pronto do `scalify\jolokia-exporter` onde o mesmo fará as leituras do endpoint jolokia e transcreverá as métricas para leitura no Prometheus na porta `9422`.

4. É adicionado conforme criador da imagem um `ConfigMap` onde passará as informações do arquivo config da imagem para transcrever as métricas JSON do Jolokia para o modelo do Prometheus. Além de um `Service` para expor o serviço na porta destinada. Para isso executaremos os seguintes manifestos:

    ```
    kubectl apply -f jolokia-exporter-service.yaml
    kubectl apply -f jolokia-configmap.yaml
    ```

6. Como iremos alterar o deployment do tomcat, devemos aplicar o novo manifesto alterado `tomcat-deploy.yaml` (presente na branch Terceira-Etapa) e podemos reiniciar o sistema usando os comando:

    ```
    kubectl apply -f tomcat-deploy.yaml
    kubectl rollout restart deployment tomcat-app
    ```

7. Feito os procedimentos tanto o Nó quanto o endpoint Jolokia estão prontos para serem lidos pelo sistema Prometheus


## Instalação e Configuração do Prometheus

1. Para instalação do Prometheus é usado um deployment da sua imagem `prom/prometheus:latest` e refereciado na porta `9090`. Para verificação do serviço de maneira externa é tambem atribuído um `NodePort` apontando para a porta externa `30090`.

2. Além disso é necessário através de um `ConfigMap` estabelecer quais os pontos de leitura que o prometheus fará em seus scraps, por isso a configuração para leitura do Jolokia Exporter, Node Exporter e do próprio prometheus é adicionado nesse manifesto.

3. Com o conhecimento de tais manifestos podemos aplicar no sistema com o comando:

   ```
    kubectl apply -f prometheus-node.yaml
    kubectl apply -f prometheus-configmap.yaml
    kubectl apply -f prometheus-deploy.yaml
   ```

4. O acesso do Prometheus então se dará pelo IP externo na porta `30090` com a leitura dos componentes acima expostos.


## Instalação e Configuração do Grafana

1. Na instalação do Grafana será também usada a imagem `grafana/grafana:latest` com exposição na porta `3000`. Para acesso externo o `NodePort` apontará para a porta `30030`.

2. Além do deploy e nodeport será também adicionado um pequeno `ConfigMap` para declarar na configuração do Grafana de imediato que a fonte de dados é o Prometheus através da porta `9090`.

3. Feita a preparação dos manifestos basta aplicar no sistema:

   ```
    kubectl apply -f grafana-node.yaml
    kubectl apply -f grafana-configmap.yaml
    kubectl apply -f grafana-deploy.yaml
   ```

## Conclusões

Após todas as aplicações é possível ter um sistema kubernetes que utilizou de uma imagem criada no docker e tem seu monitoramento com Prometheus e dashboards diretamente no Grafana.

Existem diversas possibilidades de melhora no projeto tais como:

 - Aplicação da máquina utilizando Terraform e configuração por Ansible
 - Melhoria da imagem Docker usando builder e aplicação somente com alpine
 - Aplicações de segurança no Jolokia instalado

Tais aplicações serão adicionadas aos poucos no projeto conforme segue seu desenvolvimento. Mas as descritas seguem para apresentação geral da atividade.
