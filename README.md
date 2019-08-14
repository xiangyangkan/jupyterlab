# Jupyter Lab
## 运行jupyter lab容器
   `docker run -d -p 8888:8888 -p 1234:22 -v /root/share:/root/share --name jupyter -e ROOT_PASS="jupyter" -e       PASSWORD="jupyter" -e WORK_DIR="/root/share" rivia/jupyterlab:latest`
   
   - -p 8888:8888  
     Jupyter lab映射到host主机的8888端口
   - -p 1234:22  
     通过host主机的1234端口进行ssh连接
   - -v  
     与宿主机共享的文件目录
   - --name   
     容器名称
   - ROOT_PASS   
     ssh root用户登录密钥
   - PASSWORD  
     jupyter lab登录密码，如果没有-e PASSWORD参数则无密码登录
   - WORK_DIR  
     Jupyter lab工作目录，如果没有-e WORK_DIR参数默认在/root目录下
   - `rivia/jupyterlab:latest`  
     docker镜像，即`rivia/jupyterlab:base`
   
## 运行jupyter lab的机器学习容器
   `docker run -d -p 8888:8888 -p 1234:22 -v /root/share:/root/share --name jupyter -e ROOT_PASS="jupyter" -e        PASSWORD="jupyter" -e WORK_DIR="/root/share" rivia/jupyterlab:ml`
   
   - 更换镜像为`rivia/jupyterlab:ml`

## 注意
   - 在AWS EC2上无法共享/root目录
   - debain_requirements.txt中包含要安装的debian环境，每行要空格，最后留空行
