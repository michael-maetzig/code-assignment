FROM python:3.12-slim

# Install dependencies
WORKDIR /app

# Kopiere die requirements.txt in das Arbeitsverzeichnis des Containers
COPY requirements.txt .

# Installiere die Abhängigkeiten
RUN pip install --no-cache-dir -r requirements.txt

# Kopiere den gesamten Code in das Arbeitsverzeichnis
COPY . .

# Exponiere den Port, auf dem die Flask-App läuft
EXPOSE 80

CMD ["python", "app.py"]

