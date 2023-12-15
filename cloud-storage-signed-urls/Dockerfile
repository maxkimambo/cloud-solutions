FROM python:3.11.0a1-slim-bullseye 

WORKDIR /app

COPY . .
COPY requirements.txt requirements.txt
RUN pip3 install -r requirements.txt


# CMD ["tail", "-f", "/dev/null"] 
CMD [ "python", "/app/app.py" ]