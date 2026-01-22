FROM tomcat:10.1.40-jdk17

# Instala curl para baixar o Jolokia agent
RUN apt-get update && apt-get install -y curl

#Definição das pastas de deploy
ENV CATALINA_HOME /usr/local/tomcat
ENV DEPLOY $CATALINA_HOME/webapps

# Baixa o Jolokia Agent WAR
ADD https://search.maven.org/remotecontent?filepath=org/jolokia/jolokia-agent-war/2.2.9/jolokia-agent-war-2.2.9.war $DEPLOY/jolokia.war

# Copia o Jenkins WAR
ADD https://get.jenkins.io/war-stable/2.504.1/jenkins.war $DEPLOY/jenkins.war

#Copia arquivo de configuração do Tomcat
COPY tomcat-users.xml $CATALINA_HOME/conf/tomcat-users.xml

#Copia contexto de aplicação de segurança Jolokia
COPY jolokia.xml $CATALINA_HOME/conf/Catalina/localhost/jolokia.xml

# Expõe portas do Tomcat e Jolokia
EXPOSE 8080     

CMD ["catalina.sh", "run"]
