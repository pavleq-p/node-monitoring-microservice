FROM python:3.12-slim
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py /app/app.py
WORKDIR /app
EXPOSE 8080
CMD [ "python", "app.py" ]