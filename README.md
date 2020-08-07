# Jupyter Lab
## 运行jupyter lab容器
   `docker run -d -p 8888:8888 -p 1234:22 -v /root/share:/root/share --name jupyter -e ROOT_PASS="jupyter" -e NOTEBOOK_PASS="jupyter" -e NOTEBOOK_USER='jupyter' rivia/jupyterlab:latest`
   
   - -p 8888:8888  
     Jupyter Lab访问端口映射到host主机的8888端口
   - -p 1234:22  
     Jupyter容器的22端口(SSH端口)映射到host主机的1234端口进行ssh连接
   - -v  
     与宿主机共享的文件目录，宿主机目录在前，容器目录在后
   - --name   
     容器名称
   - ROOT_PASS   
     root用户通过SSH登录容器的密钥
   - NOTEBOOK_PASS
     jupyter lab登录密码，如果没有-e NOTEBOOK_PASS参数则无密码登录
   - NOTEBOOK_USER  
     Jupyter lab用户名，Jupyter工作目录默认为/root/${NOTEBOOK_USER}
   - `rivia/jupyterlab:latest`  
     docker镜像

## 注意
   - 在AWS EC2上无法共享/root目录
   - debain_requirements.txt中包含要安装的debian环境，每行要空格，最后留空行
