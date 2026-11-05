CREATE OR REPLACE FUNCTION pg_temp.decode_url_part(p varchar)
RETURNS varchar AS
$$
SELECT convert_from(
         CAST(
           E'\\x' ||
           string_agg(
             CASE
               WHEN length(r.m[1]) = 1
                 THEN encode(convert_to(r.m[1], 'SQL_ASCII'), 'hex')
               ELSE substring(r.m[1] from 2 for 2)
             END,
             ''
           ) AS bytea
         ),
         'UTF8'
       )
FROM regexp_matches(
       replace($1, '+', ' '),
       '%[0-9a-f][0-9a-f]|.',
       'gi'
     ) AS r(m);
$$ LANGUAGE SQL IMMUTABLE STRICT;


WITH all_ads_data AS (
    SELECT
        ad_date,
        url_parameters,
        'facebook' AS source,
        campaign_name,
        adset_name,
        COALESCE(spend, 0) AS spend,
        COALESCE(impressions, 0) AS impressions,
        COALESCE(reach, 0) AS reach,
        COALESCE(clicks, 0) AS clicks,
        COALESCE(leads, 0) AS leads,
        COALESCE(value, 0) AS value
    FROM facebook_ads_basic_daily fabd
    LEFT JOIN facebook_campaign AS fc
        ON fabd.campaign_id = fc.campaign_id
    LEFT JOIN facebook_adset AS fa
        ON fabd.adset_id = fa.adset_id
    UNION ALL
    SELECT
        ad_date,
        url_parameters,
        'google' AS source,
        campaign_name,
        adset_name,
        COALESCE(spend, 0) AS spend,
        COALESCE(impressions, 0) AS impressions,
        COALESCE(reach, 0) AS reach,
        COALESCE(clicks, 0) AS clicks,
        COALESCE(leads, 0) AS leads,
        COALESCE(value, 0) AS value
    FROM google_ads_basic_daily
),
prepared_data AS (
    SELECT
        ad_date,
        source,
        campaign_name,
        adset_name,
        CASE
            WHEN LOWER(SUBSTRING(url_parameters, 'utm_campaign=([^&]+)')) IS NULL THEN NULL
            WHEN LOWER(SUBSTRING(url_parameters, 'utm_campaign=([^&]+)')) = 'nan' THEN NULL
            ELSE decode_url_part(
                LOWER(SUBSTRING(url_parameters, 'utm_campaign=([^&]+)'))
            )
        END AS utm_campaign,
        spend,
        impressions,
        reach,
        clicks,
        leads,
        value
    FROM all_ads_data
)
SELECT
    ad_date,
    source,
    campaign_name,
    adset_name,
    utm_campaign,
    SUM(spend) AS total_spend,
    SUM(impressions) AS total_impressions,
    SUM(reach) AS total_reach,
    SUM(clicks) AS total_clicks,
    SUM(leads) AS total_leads,
    SUM(value) AS total_value
FROM prepared_data
GROUP BY
    ad_date,
    source,
    utm_campaign,
    campaign_name,
    adset_name
ORDER BY
    ad_date,
    source,
    utm_campaign;