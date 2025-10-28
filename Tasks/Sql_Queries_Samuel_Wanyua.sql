-- =========================================
-- TASK 3: SQL QUERY WRITING
-- Author: Samuel Wanyua
-- Goal: Analyze property and lease data
-- =========================================

-- Create and use the database
CREATE DATABASE IF NOT EXISTS real_estate_task;
USE real_estate_task;

-- ============================================================
-- 1️. OCCUPANCY UNDERPERFORMERS
-- Properties with occupancy rate below 80%
-- Occupancy = (occupied_units / total_units) * 100
-- Only valid_lease = 1 counts as occupied
-- ============================================================

WITH unit_occupancy AS (
    SELECT 
        u.property_id,
        COUNT(DISTINCT u.id) AS total_units,
        COUNT(DISTINCT CASE WHEN l.valid_lease = 1 THEN u.id END) AS occupied_units
    FROM units u
    LEFT JOIN leases l ON u.id = l.unit_id
    GROUP BY u.property_id
)
SELECT 
    p.id AS property_id,
    p.property_name,
    ROUND((uo.occupied_units * 100.0 / uo.total_units), 2) AS occupancy_rate
FROM unit_occupancy uo
JOIN properties p ON p.id = uo.property_id
WHERE (uo.occupied_units * 100.0 / uo.total_units) < 80
ORDER BY occupancy_rate ASC;

-- ============================================================
-- 2️. ARREARS BY LOCATION
-- Return total arrears per location, including zero
-- ============================================================

SELECT 
    loc.location_name AS location,
    COALESCE(SUM(l.arrears), 0) AS total_arrears
FROM locations loc
LEFT JOIN properties p ON loc.id = p.location_id
LEFT JOIN units u ON p.id = u.property_id
LEFT JOIN leases l ON u.id = l.unit_id
GROUP BY loc.location_name
ORDER BY total_arrears DESC;

-- 3️. COLLECTION EFFICIENCY LEADERBOARD (TOP 3)
-- Formula: (1 - SUM(arrears) / NULLIF(SUM(rent_per_month), 0)) * 100
-- Only valid leases are considered

SELECT 
    p.property_name,
    ROUND((1 - (SUM(l.arrears) / NULLIF(SUM(l.rent_per_month), 0))) * 100, 2) AS collection_efficiency
FROM properties p
JOIN units u ON p.id = u.property_id
JOIN leases l ON u.id = l.unit_id
WHERE l.valid_lease = 1
GROUP BY p.property_name
ORDER BY collection_efficiency DESC
LIMIT 3;

-- ============================================================
-- 4️. DATA QUALITY CHECK – INVALID LEASES
-- Leases with negative rent or end_date < start_date
-- ============================================================

SELECT 
    l.id AS lease_id,
    p.property_name,
    u.unit_name,
    t.tenant_name,
    CASE 
        WHEN l.rent_per_month < 0 THEN 'NEGATIVE_RENT'
        WHEN l.end_date < l.start_date THEN 'END_BEFORE_START'
    END AS reason_flag
FROM leases l
JOIN units u ON l.unit_id = u.id
JOIN properties p ON u.property_id = p.id
JOIN tenants t ON l.tenant_id = t.id
WHERE l.rent_per_month < 0 OR l.end_date < l.start_date
ORDER BY lease_id;

-- 5️. MULTI-UNIT TENANTS
-- Tenants holding 2+ distinct units (current or historical)

SELECT 
    t.tenant_name,
    COUNT(DISTINCT l.unit_id) AS unit_count,
    GROUP_CONCAT(DISTINCT p.property_name ORDER BY p.property_name SEPARATOR ', ') AS properties_spanned
FROM tenants t
JOIN leases l ON t.id = l.tenant_id
JOIN units u ON l.unit_id = u.id
JOIN properties p ON u.property_id = p.id
GROUP BY t.tenant_name
HAVING COUNT(DISTINCT l.unit_id) >= 2
ORDER BY unit_count DESC;
