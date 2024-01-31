# run stage
FROM python:3.9-slim

# set working directory
WORKDIR /project

# copy the rest of the application files
COPY requirements.txt /project/
# install dependencies
RUN pip install --no-cache-dir -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple

COPY app /project/app
COPY scripts/entrypoint.sh /

EXPOSE 80

# set command/entrypoint, adapt to fit your needs
ENTRYPOINT ["sh", "/entrypoint.sh"]
