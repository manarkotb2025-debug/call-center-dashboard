create database callcenter
CREATE TABLE departments (
    department_id INT PRIMARY KEY,
    department_name VARCHAR(100)
);
CREATE TABLE agents (
    agent_id INT PRIMARY KEY,
    agent_name VARCHAR(100),
    gender VARCHAR(10),
    date_of_birth DATE,
    department_id INT,
    team_manager VARCHAR(100),

    FOREIGN KEY (department_id) REFERENCES departments(department_id)
);
CREATE TABLE dim_date (
    date_id INT PRIMARY KEY IDENTITY(1,1),
    full_date DATE,
    day INT,
    month INT,
    year INT
);
CREATE TABLE calls (
    call_id INT PRIMARY KEY IDENTITY(1,1),
    date_time DATETIME,
    agent_id INT,
    department_id INT,
    talk_time INT,
    hold_time INT,
    acw_time INT,
    waiting_time INT,
    call_transferred BIT,

    FOREIGN KEY (agent_id) REFERENCES agents(agent_id),
    FOREIGN KEY (department_id) REFERENCES departments(department_id)
);
CREATE TABLE abandoned_calls (
    abandon_id INT PRIMARY KEY IDENTITY(1,1),
    date_time DATETIME,
    agent_id INT,
    department_id INT,
    abandonment_time INT,

    FOREIGN KEY (agent_id) REFERENCES agents(agent_id),
    FOREIGN KEY (department_id) REFERENCES departments(department_id)
);
CREATE TABLE forecast (
    forecast_id INT PRIMARY KEY IDENTITY(1,1),
    date DATE,
    department_id INT,
    interval VARCHAR(50),
    forecast_calls INT,

    FOREIGN KEY (department_id) REFERENCES departments(department_id)
);
CREATE TABLE surveys (
    survey_id INT PRIMARY KEY,
    date_time DATETIME,
    agent_id INT,
    recommend_score INT,
    satisfaction_score INT,
    resolution BIT,

    FOREIGN KEY (agent_id) REFERENCES agents(agent_id)
);


-- sql staging in raw data --

SELECT 
    CAST(DateColumn AS DATETIME) + CAST(TimeColumn AS DATETIME) AS date_time
FROM dbo.raw_calls;

SELECT * FROM dbo.raw_calls
WHERE Agent_ID IS NULL
   OR Department_ID IS NULL
   OR DateColumn IS NULL
   OR TimeColumn IS NULL;


-- departments cleaning--
-- Missing Values
SELECT * FROM dbo.raw_Departments
WHERE Department_ID IS NULL OR Department_Name IS NULL;

-- Duplicates
SELECT Department_ID, COUNT(*)
FROM dbo.raw_Departments
GROUP BY Department_ID
HAVING COUNT(*) > 1;
-- agents cleaning--
-- Missing Values
SELECT * FROM dbo.raw_Agents
WHERE Agent_ID IS NULL OR Agent_Name IS NULL 
   OR Gender IS NULL OR Date_of_Birth IS NULL
   OR Department_ID IS NULL OR Team_Manager IS NULL;

-- Duplicates
SELECT Agent_ID, COUNT(*)
FROM dbo.raw_Agents
GROUP BY Agent_ID
HAVING COUNT(*) > 1;

-- Missing Values abondent
SELECT * FROM dbo.raw_Abandoned
WHERE Date IS NULL OR Time IS NULL
   OR Department_ID IS NULL OR Abandonment_Time_seconds IS NULL;

-- Missing Values forcast
SELECT * FROM dbo.raw_Forecast
WHERE Date IS NULL OR Department_ID IS NULL
   OR Interval IS NULL OR Forecast_Calls IS NULL;

SELECT * FROM dbo.raw_Surveys
WHERE Survey_ID IS NULL OR Date_and_Time IS NULL
   OR Agent_ID IS NULL OR Recommend_Score IS NULL
   OR Satisfaction_Score IS NULL OR Resolution IS NULL;


INSERT INTO departments (department_id, department_name)
SELECT Department_ID, Department_Name
FROM dbo.raw_Departments;

INSERT INTO agents (agent_id, agent_name, gender, date_of_birth, department_id, team_manager)
SELECT Agent_ID, Agent_Name, Gender, Date_of_Birth, Department_ID, Team_Manager
FROM dbo.raw_Agents;

INSERT INTO calls (date_time, agent_id, department_id, talk_time, hold_time, acw_time, waiting_time, call_transferred)
SELECT 
    CAST(DateColumn AS DATETIME) + CAST(TimeColumn AS DATETIME),
    Agent_ID, Department_ID, Talk_Time, Hold_Time, ACW_Time, Waiting_Time, Call_Transferred
FROM dbo.raw_calls;

INSERT INTO abandoned_calls (date_time, department_id, abandonment_time)
SELECT 
    CAST(Date AS DATETIME) + CAST(Time AS DATETIME),
    Department_ID,
    Abandonment_Time_seconds
FROM dbo.raw_Abandoned;


INSERT INTO forecast (date, department_id, interval, forecast_calls)
SELECT Date, Department_ID, Interval, Forecast_Calls
FROM dbo.raw_Forecast;

INSERT INTO surveys (survey_id, date_time, agent_id, recommend_score, satisfaction_score, resolution)
SELECT 
    Survey_ID,
    CONVERT(DATETIME, Date_and_Time, 103),
    Agent_ID,
    Recommend_Score,
    Satisfaction_Score,
    Resolution
FROM dbo.raw_Surveys;

ALTER TABLE surveys
DROP CONSTRAINT PK__surveys__9DC31A07BA746C15;

ALTER TABLE surveys
ALTER COLUMN survey_id VARCHAR(10) Not Null;

-- 3) حط الـ Primary Key تاني
ALTER TABLE surveys
ADD CONSTRAINT PK_surveys PRIMARY KEY (survey_id);

WITH dates AS (
    SELECT CAST('2023-01-01' AS DATE) AS full_date
    UNION ALL
    SELECT DATEADD(DAY, 1, full_date)
    FROM dates
    WHERE full_date < '2025-12-31'
)




---kpi total calls
SELECT COUNT(*) AS total_calls
FROM calls;

---aht
SELECT AVG(talk_time + hold_time + acw_time) AS AHT
FROM calls;

---total calls and average talk time per dep
CREATE VIEW v_calls_kpis AS
SELECT 
    d.department_name,
    COUNT(c.call_id) AS total_calls,
    AVG(c.talk_time) AS avg_talk_time
FROM calls c
JOIN departments d ON c.department_id = d.department_id
GROUP BY d.department_name;
---abondent rate
SELECT 
(SELECT COUNT(*) FROM abandoned_calls) * 1.0 /
(SELECT COUNT(*) FROM calls) AS abandon_rate;
--total calls per department
SELECT d.department_name, COUNT(*) AS total_calls
FROM calls c
JOIN departments d ON c.department_id = d.department_id
GROUP BY d.department_name
ORDER BY total_calls DESC;
--peak hours
SELECT DATEPART(HOUR, date_time) AS hour,
COUNT(*) AS total_calls
FROM calls
GROUP BY DATEPART(HOUR, date_time)
ORDER BY total_calls DESC;
--best 5 agents
SELECT TOP 5
    a.agent_name,
    COUNT(*) AS total_calls,
    AVG(talk_time + hold_time + acw_time) AS AHT
FROM calls c
JOIN agents a ON c.agent_id = a.agent_id
GROUP BY a.agent_name
ORDER BY total_calls DESC;
--best team manager

SELECT a.team_manager,
COUNT(*) AS total_calls,
AVG(talk_time) AS avg_talk
FROM calls c
JOIN agents a ON c.agent_id = a.agent_id
GROUP BY a.team_manager
ORDER BY total_calls DESC;

----csat

SELECT AVG(satisfaction_score) AS CSAT
FROM surveys;



---nps

SELECT 
    CASE 
        WHEN recommend_score >= 9 THEN 'Promoter'
        WHEN recommend_score >= 7 THEN 'Passive'
        ELSE 'Detractor'
    END AS customer_type,
    COUNT(*) AS total
FROM surveys
GROUP BY 
    CASE 
        WHEN recommend_score >= 9 THEN 'Promoter'
        WHEN recommend_score >= 7 THEN 'Passive'
        ELSE 'Detractor'
    END;


SELECT 
    customer_type,
    COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS percentage
FROM (
    SELECT 
        CASE 
            WHEN recommend_score >= 9 THEN 'Promoter'
            WHEN recommend_score >= 7 THEN 'Passive'
            ELSE 'Detractor'
        END AS customer_type
    FROM surveys
) t
GROUP BY customer_type;

