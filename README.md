# Projeto SigaBox

Este repositório busca demonstrar as instruções para execução dos procedimentos solicitados da atividade solicitada

## Sumário

- [Pré-requisitos](#pré-requisitos)
- [Construção da Máquina Operacional](#construção-da-máquina-operacional)
- [Execução Docker do Serviço](#execução-docker-do-serviço)
- [Instalação e controle via Kubernetes](#instalação-e-controle-via-kubernetes)

## Pré-requisitos

1. Conta AWS
2. Máquina EC2 para operação de serviço

---

## Construção da Máquina Operacional

Para executar a criação do servidor será necessário criar uma máquina EC2 para controle dos serviços internos do sistema. Assim como sistema Terraform e Ansible para criação e configuração das máquinas.

### Passos:

1. Criar uma infraestrutura básica na AWS com as seguintes propriedades
    - OS: ubuntu 22.04
    - região: us-east-1 (mas pode ser qualquer outra)
    - Tipo de Instância: t3.small
    - Armazenamento: 15 Gb
    - Criar par de chaves para uso
    - Grupo de Segurança: Liberação das portas ssh (22) e TCP (80, 8080, 30080)
    - Criar e vincular IP elástico para facilitar conexões futuras
    
2. Primeiramente é necessário adicionar uma pasta para execução do projeto, a mesma pode se ter o próprio nome do repositório

3. Para executar os serviços necessários serão utilizados o docker e o kubeadm para o cluster na máquina AWS.

Pra instalação do Docker segue-se a documentação do site https://docs.docker.com/engine/install/ubuntu/ onde se segue instruções para preparação do repositório `apt`. Feita a preparação basta instalar os plugins necessários

```
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```
Com a instalação desse sistema o docker estará pronto para criação de imagens e containers

4. A instalação do Kubernetes estará usando o Kubeadm, por isso é necessário seguir uma ordem de instalação para sua execução, assim como aderir a um CNI (Container Network Interface) para controle de rede interna.
   



   
---

## Execução Docker do Serviço

### Montagem do ambiente

1. É Criado o arquivo *Dockerfile* com a versão tomcat 9 para uso do container que já existe na biblioteca Docker.
2. É criado uma imagem usando o comando *docker build -t tomcat:1.0 .* onde é marcado a versão e execução na pasta do comando
3. É executada a imagem com *docker run -d -p 8080:8080 --name tomcat tomcat:1.0*
4. Fica disponibilizada a imagem com Jenkins disponível para uso.

---

## Instalação e controle via Kubernetes


1. Com o Kubeadm instalado iremos 
