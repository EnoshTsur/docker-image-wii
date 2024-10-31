# Dockerfile
FROM postgres:latest

# Set environment variables for PostgreSQL
ENV POSTGRES_USER=admin
ENV POSTGRES_PASSWORD=1234
ENV POSTGRES_DB=missions_db

# Copy the CSV file to the Docker image
COPY missions.csv /docker-entrypoint-initdb.d/missions.csv
COPY init.sql /docker-entrypoint-initdb.d/init.sql