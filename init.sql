-- Create and load raw staging table from CSV
CREATE TABLE raw_staging (
    "Mission ID" INTEGER,
    "Mission Date" DATE,
    "Theater of Operations" VARCHAR(100),
    "Country" VARCHAR(200),
    "Air Force" VARCHAR(100),
    "Unit ID" VARCHAR(100),
    "Aircraft Series" VARCHAR(50),
    "Callsign" VARCHAR(100),
    "Mission Type" VARCHAR(200),
    "Takeoff Base" VARCHAR(200),
    "Takeoff Location" VARCHAR(200),
    "Takeoff Latitude" VARCHAR(200),
    "Takeoff Longitude" VARCHAR(200),
    "Target ID" VARCHAR(200),
    "Target Country" VARCHAR(200),
    "Target City" VARCHAR(200),
    "Target Type" TEXT,
    "Target Industry" TEXT,
    "Target Priority" VARCHAR(10),
    "Target Latitude" VARCHAR(200),
    "Target Longitude" VARCHAR(200),
    "Altitude (Hundreds of Feet)" DECIMAL(10, 2),
    "Airborne Aircraft" DECIMAL(10, 2),
    "Attacking Aircraft" DECIMAL(10, 2),
    "Bombing Aircraft" DECIMAL(10, 2),
    "Aircraft Returned" DECIMAL(10, 2),
    "Aircraft Failed" DECIMAL(10, 2),
    "Aircraft Damaged" DECIMAL(10, 2),
    "Aircraft Lost" DECIMAL(10, 2),
    "High Explosives" DECIMAL(10, 2),
    "High Explosives Type" TEXT,
    "High Explosives Weight (Pounds)" VARCHAR(200),
    "High Explosives Weight (Tons)" VARCHAR(200),
    "Incendiary Devices" DECIMAL(10, 2),
    "Incendiary Devices Type" TEXT,
    "Incendiary Devices Weight (Pounds)" VARCHAR(200),
    "Incendiary Devices Weight (Tons)" VARCHAR(200),
    "Fragmentation Devices" DECIMAL(10, 2),
    "Fragmentation Devices Type" TEXT,
    "Fragmentation Devices Weight (Pounds)" VARCHAR(200),
    "Fragmentation Devices Weight (Tons)" VARCHAR(200),
    "Total Weight (Pounds)" VARCHAR(200),
    "Total Weight (Tons)" VARCHAR(200),
    "Time Over Target" VARCHAR(100),
    "Bomb Damage Assessment" TEXT,
    "Source ID" INTEGER
);

-- Load data from CSV
COPY raw_staging FROM '/docker-entrypoint-initdb.d/missions.csv' DELIMITER ',' CSV HEADER;

CREATE TABLE Missions (
    mission_id INTEGER PRIMARY KEY,
    mission_date DATE,
    airborne_aircraft DECIMAL(10, 2),
    attacking_aircraft DECIMAL(10, 2),
    bombing_aircraft DECIMAL(10, 2),
    aircraft_returned DECIMAL(10, 2),
    aircraft_failed DECIMAL(10, 2),
    aircraft_damaged DECIMAL(10, 2),
    aircraft_lost DECIMAL(10, 2)
);

-- Insert data into Missions
INSERT INTO missions (
    mission_id,
    mission_date,
    airborne_aircraft,
    attacking_aircraft,
    bombing_aircraft,
    aircraft_returned,
    aircraft_failed,
    aircraft_damaged,
    aircraft_lost
)
SELECT 
    "Mission ID",
    "Mission Date",
    "Airborne Aircraft",
    "Attacking Aircraft",
    "Bombing Aircraft",
    "Aircraft Returned",
    "Aircraft Failed",
    "Aircraft Damaged",
    "Aircraft Lost"
FROM raw_staging;

-- Create normalized tables
CREATE TABLE Countries (
    country_id serial primary key,
    country_name varchar(100) unique not null
);

CREATE TABLE Cities (
    city_id serial primary key,
    city_name varchar(100),
    country_id int not null,
    latitude decimal,
    longitude decimal,
    foreign key (country_id) references Countries(country_id),
    UNIQUE (city_name, country_id)  -- Changed from unique city_name to unique combination
);

CREATE TABLE TargetTypes (
    target_type_id serial primary key,
    target_type_name varchar(255) unique not null
);

CREATE TABLE Targets (
    target_id serial primary key,
    mission_id INTEGER,              -- Added mission_id
    target_industry varchar(255) not null,
    city_id int not null,
    target_type_id int,
    target_priority int,
    foreign key (city_id) references Cities(city_id),
    foreign key (target_type_id) references TargetTypes(target_type_id),
    foreign key (mission_id) references missions(mission_id)
);


-- Insert into Countries
INSERT INTO countries (country_name)
SELECT DISTINCT "Target Country"
FROM raw_staging
WHERE "Target Country" IS NOT NULL
ON CONFLICT (country_name) DO NOTHING;

-- Insert into Cities
INSERT INTO cities (city_name, country_id, latitude, longitude)
SELECT DISTINCT ON (rs."Target City", rs."Target Country")
    rs."Target City",
    c.country_id,
    NULLIF(rs."Target Latitude", '')::DECIMAL,
    NULLIF(rs."Target Longitude", '')::DECIMAL
FROM raw_staging rs
JOIN countries c ON rs."Target Country" = c.country_name
WHERE rs."Target City" IS NOT NULL
ON CONFLICT (city_name, country_id) DO NOTHING;

-- Insert into TargetTypes
INSERT INTO targettypes (target_type_name)
SELECT DISTINCT "Target Type"
FROM raw_staging
WHERE "Target Type" IS NOT NULL
ON CONFLICT (target_type_name) DO NOTHING;

-- Insert into Targets
INSERT INTO targets (mission_id, target_industry, city_id, target_type_id, target_priority)
SELECT DISTINCT ON (rs."Mission ID", rs."Target Industry", rs."Target City", rs."Target Country", rs."Target Type")
    rs."Mission ID",
    rs."Target Industry",
    c.city_id,
    tt.target_type_id,
    NULLIF(rs."Target Priority", '')::INTEGER
FROM raw_staging rs
JOIN cities c ON rs."Target City" = c.city_name
JOIN countries co ON rs."Target Country" = co.country_name AND c.country_id = co.country_id
JOIN targettypes tt ON rs."Target Type" = tt.target_type_name
JOIN missions m ON rs."Mission ID" = m.mission_id  -- Add this JOIN to ensure mission exists
WHERE rs."Target Industry" IS NOT NULL;


-- Clean up
DROP TABLE raw_staging;