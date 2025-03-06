-- ## Lahman Baseball Database Exercise
-- - this data has been made available [online](http://www.seanlahman.com/baseball-archive/statistics/) by Sean Lahman
-- - you can find a data dictionary [here](http://www.seanlahman.com/files/database/readme2016.txt)

-- 1. Find all players in the database who played at Vanderbilt University. Create a list showing each player's first and last names as well as the total salary they earned in the major leagues. Sort this list in descending order by the total salary earned. Which Vanderbilt player earned the most money in the majors?
   WITH vandy_players AS (
    SELECT DISTINCT playerid
    FROM collegeplaying
    WHERE schoolid = 'vandy')

   
   SELECT namefirst ||' '|| namelast, CAST(SUM(salary) AS NUMERIC)::money AS money
   FROM people
   INNER JOIN salaries
   USING (playerid)
   INNER JOIN vandy_players
   USING(playerid)
   GROUP BY namefirst, namelast
   ORDER BY money DESC;

  -- FROM schools
   --INNER JOIN collegeplaying
   --USING(schoolid)

   --or

   WITH vandy_players AS (
    SELECT DISTINCT playerid
    FROM collegeplaying
    WHERE schoolid = 'vandy'
)
SELECT 
    namefirst || ' ' || namelast AS fullname, 
    SUM(salary)::int::MONEY AS total_salary
FROM salaries
INNER JOIN vandy_players
USING(playerid)
INNER JOIN people
USING(playerid)
GROUP BY fullname
ORDER BY total_salary DESC
LIMIT 5;

--or

SELECT namefirst, namelast, SUM(salary) AS total_salary
FROM people
INNER JOIN salaries
USING(playerid)
WHERE playerid IN (
	SELECT DISTINCT playerid
	FROM collegeplaying
	LEFT JOIN schools
	USING(schoolid)
	WHERE schoolname = 'Vanderbilt University')
GROUP BY playerid
ORDER BY total_salary DESC;

-- 2. Using the fielding table, group players into three groups based on their position: label players with position OF as "Outfield", those with position "SS", "1B", "2B", and "3B" as "Infield", and those with position "P" or "C" as "Battery". Determine the number of putouts made by each of these three groups in 2016.

   SELECT
	   SUM(po) AS putout_num,
       CASE WHEN pos = 'OF' THEN 'Outfield'
	        WHEN pos IN ('SS', '1B', '2B', '3B') THEN 'Infield'
			WHEN pos IN('P', 'C') THEN 'Battery' ELSE 'NULL' END AS position
   FROM fielding
   WHERE yearid = 2016
   GROUP BY position;

   --or

   SELECT
	CASE WHEN pos = 'OF' THEN 'Outfield'
	 WHEN pos IN ('SS', '1B', '2B', '3B') THEN 'Infield'
	 WHEN pos IN ('P', 'C') THEN 'Battery'
	 END AS player_group,
	 SUM(po) AS total_putouts
FROM fielding
WHERE yearid = 2016
GROUP BY player_group
ORDER BY total_putouts;

-- 3. Find the average number of strikeouts per game by decade since 1920. Round the numbers you report to 2 decimal places. Do the same for home runs per game. Do you see any trends? (Hint: For this question, you might find it helpful to look at the **generate_series** function (https://www.postgresql.org/docs/9.1/functions-srf.html). If you want to see an example of this in action, check out this DataCamp video: https://campus.datacamp.com/courses/exploratory-data-analysis-in-sql/summarizing-and-aggregating-numeric-data?ex=6)
WITH decade_int AS(
     SELECT generate_series(1920,2010,10) AS lower,
	        generate_series(1930,2020,10) AS upper)

SELECT lower, upper, ROUND((CAST(SUM(so) AS NUMERIC))/(CAST(SUM(g) AS NUMERIC)/2), 2) AS avg_so, ROUND((CAST(SUM(hr) AS NUMERIC))/(CAST(SUM(g) AS NUMERIC)/2), 2) AS avg_hr
 FROM decade_int
 LEFT JOIN teams
 ON yearid >= lower AND yearid <= upper
 GROUP BY lower, upper
 ORDER BY lower, upper;

 --or

WITH decades AS (
	SELECT generate_series(1920, MAX(yearid), 10) AS decade_start
	, generate_series(1929, (MAX(yearid) + 10), 10) AS decade_end
	FROM batting
)
SELECT 
	decade_start
	, decade_end
	, ROUND(SUM(so)::numeric/SUM(g)::numeric, 2) as total_so
	, ROUND(SUM(hr)::numeric/SUM(g)::numeric, 2) as total_hr
	/***
	depends on how you count the games, if orioles vs braves, orioles gets counted once and 
	braves get counted once, so you can divide by two OR leave as is depending on your understanding
	***/
	-- , ROUND(SUM(hr) * 1.0 / (SUM(g) / 2.0), 2) AS hr_per_game
	-- , ROUND(SUM(so) * 1.0 / (SUM(g) / 2.0), 2) AS so_per_game 
FROM decades a 
LEFT JOIN teams b 
ON b.yearid >= a.decade_start
AND b.yearid <= a.decade_end
WHERE b.yearid >= 1920
GROUP BY 1,2
ORDER BY 1,2;

-- 4. Find the player who had the most success stealing bases in 2016, where __success__ is measured as the percentage of stolen base attempts which are successful. (A stolen base attempt results either in a stolen base or being caught stealing.) Consider only players who attempted _at least_ 20 stolen bases. Report the players' names, number of stolen bases, number of attempts, and stolen base percentage.

SELECT playerid, namefirst || ' ' || namelast AS player_name, sb AS stolen_bases, (sb + cs) AS attempted_bases, ROUND(100 * (CAST(sb AS NUMERIC)/CAST((sb + cs) AS NUMERIC)), 2) AS stolen_base_percentage
FROM people
LEFT JOIN batting
USING(playerid)
WHERE yearid = 2016
AND (sb + cs) >= 20
GROUP BY playerid, namefirst, namelast, sb, cs
ORDER BY stolen_base_percentage DESC
LIMIT 5;

--or

WITH full_batting AS (
	SELECT
		playerid,
		SUM(sb) AS sb,
		SUM(cs) AS cs
	FROM batting
	WHERE yearid = 2016
	GROUP BY playerid
)
SELECT
	namefirst || ' ' || namelast AS full_name,
	sb, 
	sb + cs AS attempts,
	ROUND(sb * 100.0 / (sb + cs), 1) AS sb_pct
FROM full_batting
INNER JOIN people
USING(playerid)
WHERE sb + cs >= 20
ORDER BY sb_pct DESC
LIMIT 5;

--Chris Owings had the most success stealing bases in 2016.


-- 5. From 1970 to 2016, what is the largest number of wins for a team that did not win the world series? What is the smallest number of wins for a team that did win the world series? Doing this will probably result in an unusually small number of wins for a world series champion; determine why this is the case. Then redo your query, excluding the problem year. How often from 1970 to 2016 was it the case that a team with the most wins also won the world series? What percentage of the time?

(SELECT teamID, name AS team, yearid, W, wswin
FROM teams
WHERE yearid >= 1970
AND yearid <= 2016
AND wswin = 'N'
GROUP BY teamID, name, yearid, W, wswin
ORDER BY W DESC
LIMIT 1)
UNION
(SELECT teamID, name AS team, yearid, W, wswin
FROM teams
WHERE yearid >= 1970
AND yearid <= 2016
AND wswin = 'Y'
GROUP BY teamID, name, yearid, W, wswin
ORDER BY W
LIMIT 1);

--The resulting query above shows that the Seattle Mariners had the largest number of wins for a team that did not win the world series between 1970 and 2016 in 2001,
--and that the Los Angeles Dodgers had the smallest number of wins for a team that did win the world series between 1970 and 2016 in 1981.

SELECT teamid, name AS team, W, wswin
FROM teams
WHERE yearid = 1981
GROUP BY teamid, name, W, wswin
ORDER BY W DESC;

--The number of wins for LAN in 1981 seemed unusually low for a team that won the world series that year, so the query above reveals two teams having more wins in 1981 than the team that won the world series that year.
WITH CTE_1 AS (
SELECT yearid, MAX(W) AS most_wins_per_year
FROM teams
WHERE yearid >= 1970
AND yearid <= 2016
AND yearid != 1981
GROUP BY yearid
ORDER BY yearid),

ws_max_table AS (
SELECT
     yearid,
     CASE WHEN wswin = 'Y' AND most_wins_per_year = W THEN 1
	      WHEN wswin = 'N' AND most_wins_per_year = W THEN 0 END AS ws_win_max
FROM teams
INNER JOIN CTE_1
USING(yearid)
GROUP BY yearid, wswin, most_wins_per_year, W
ORDER BY yearid)

SELECT ROUND(100 * (CAST(SUM(ws_win_max) AS NUMERIC)/CAST(COUNT(DISTINCT yearid) AS NUMERIC)), 2) AS ws_win_max_percentage
, SUM(ws_win_max) AS ws_win_max_count, COUNT(DISTINCT yearid) AS year_num
FROM ws_max_table;

--or

WITH most_wins AS (
    SELECT
        yearid,
        MAX(w) AS w
    FROM teams
    WHERE yearid >= 1970
    GROUP BY yearid
    ORDER BY yearid
    ),
ws_winners_with_most_wins AS (
    SELECT 
        yearid,
        teamid,
        w
    FROM teams
    INNER JOIN most_wins
    USING(yearid, w)
    WHERE wswin = 'Y'
),
ws_years AS (
    SELECT COUNT(DISTINCT yearid)
    FROM teams
    WHERE wswin = 'Y' AND yearid >= 1970
)
SELECT 
    (SELECT COUNT(*) FROM ws_winners_with_most_wins) AS num_most_win_ws_winners,
    (SELECT * FROM ws_years) as years_with_ws,
    ROUND((SELECT COUNT(*)
     FROM ws_winners_with_most_wins
    ) * 100.0 /
    (SELECT *
     FROM ws_years
    ), 2) AS most_wins_ws_pct
    ;

	--or

	with filtered_table AS (
SELECT 
    yearid
    , teamid
    , WSWin
    , w
    , RANK() OVER (PARTITION BY yearid ORDER BY w DESC) AS rank
FROM teams
WHERE yearid >= 1970
AND yearid <= 2016
AND yearid <> 1981 --the problem year
)
SELECT 
    ROUND(SUM(CASE WHEN wswin = 'Y' THEN 1 END ) / SUM(rank) * 100 ,2) 
    /***
    this is 12/52 TEAMS whereas 12/46 YEARS this happens. Rank doesn't account for ties
    ***/
FROM filtered_table 
WHERE rank=1;

-- 6. Which managers have won the TSN Manager of the Year award in both the National League (NL) and the American League (AL)? Give their full name and the teams that they were managing when they won the award.

WITH CTE AS (
SELECT playerid
FROM awardsmanagers
WHERE awardid = 'TSN Manager of the Year'
AND lgid IN ('NL', 'AL')
GROUP BY playerid
HAVING COUNT(DISTINCT lgid) = 2)

SELECT namefirst || ' ' || namelast AS full_name, teams.name, yearid, teams.lgid
FROM CTE
INNER JOIN people
USING(playerid)
INNER JOIN awardsmanagers
USING(playerid)
INNER JOIN managers
USING(playerid, yearid, lgid)
INNER JOIN teams
USING(teamid, yearid)
WHERE awardid = 'TSN Manager of the Year';

--or

with winners AS (
SELECT 
    playerid
    , COUNT(DISTINCT lgid) as leagues_won
FROM awardsmanagers
WHERE awardid LIKE '%TSN%'
AND lgid IN ('NL', 'AL')
GROUP BY 1
)
, dual_leagues AS (
SELECT 
    yearid
    , playerid
FROM (SELECT playerid FROM winners WHERE leagues_won > 1) a
LEFT JOIN awardsmanagers b
USING(playerid)
WHERE awardid LIKE '%TSN%'
)
SELECT
    namefirst
    , namelast
    , teamid
    , yearid
FROM dual_leagues a
LEFT JOIN managers
USING (yearid, playerid)
LEFT JOIN people
USING (playerid);

-- 7. Which pitcher was the least efficient in 2016 in terms of salary / strikeouts? Only consider pitchers who started at least 10 games (across all teams). Note that pitchers often play for more than one team in a season, so be sure that you are counting all stats for each player.

WITH CTE AS(SELECT playerid, SUM(gs) AS total_games_started, SUM(so) AS total_strikeouts, yearid
FROM pitching
WHERE yearid = 2016
GROUP BY playerid, yearid
HAVING SUM(gs) >= 10)

SELECT namefirst|| ' ' ||namelast AS full_name, SUM(salary)/total_strikeouts AS salary_per_strikeouts
FROM CTE
INNER JOIN salaries
USING(playerid, yearid)
INNER JOIN people
USING(playerid)
GROUP BY playerid, namefirst, namelast, total_strikeouts
ORDER BY salary_per_strikeouts DESC;

-- 8. Find all players who have had at least 3000 career hits. Report those players' names, total number of hits, and the year they were inducted into the hall of fame (If they were not inducted into the hall of fame, put a null in that column.) Note that a player being inducted into the hall of fame is indicated by a 'Y' in the **inducted** column of the halloffame table.

WITH CTE AS (SELECT playerid, SUM(h) AS total_hits
FROM batting
GROUP BY playerid
HAVING SUM(h) >= 3000)

SELECT namefirst || ' ' || namelast AS full_name, CTE.total_hits, halloffame.yearid, 
     CASE WHEN halloffame.inducted = 'N' THEN NULL
	      WHEN halloffame.inducted = 'Y' THEN 'Y' END AS inducted
FROM CTE
INNER JOIN people
USING(playerid)
INNER JOIN halloffame
USING(playerid)
GROUP BY namefirst, namelast, CTE.total_hits, halloffame.yearid, halloffame.inducted;

-- 9. Find all players who had at least 1,000 hits for two different teams. Report those players' full names.

WITH CTE_1 AS(SELECT batting.playerid, SUM(batting.h) AS total_hits, teams.name AS team_name
FROM batting
INNER JOIN teams
USING(teamid, yearid)
GROUP BY batting.playerid, teams.name
HAVING SUM(batting.h) >= 1000),

CTE_2 AS (SELECT CTE_1.playerid
FROM CTE_1
INNER JOIN people
USING(playerid)
GROUP BY CTE_1.playerid
HAVING COUNT(DISTINCT CTE_1.team_name) >= 2)

SELECT namefirst || ' ' || namelast AS full_name, team_name, total_hits
FROM CTE_2
INNER JOIN CTE_1
USING(playerid)
INNER JOIN people
USING(playerid)
GROUP BY namefirst, namelast, team_name, total_hits
ORDER BY full_name;

-- 10. Find all players who hit their career highest number of home runs in 2016. Consider only players who have played in the league for at least 10 years, and who hit at least one home run in 2016. Report the players' first and last names and the number of home runs they hit in 2016.



-- After finishing the above questions, here are some open-ended questions to consider.

-- **Open-ended questions**

-- 11. Is there any correlation between number of wins and team salary? Use data from 2000 and later to answer this question. As you do this analysis, keep in mind that salaries across the whole league tend to increase together, so you may want to look on a year-by-year basis.

-- 12. In this question, you will explore the connection between number of wins and attendance.

--     a. Does there appear to be any correlation between attendance at home games and number of wins?  
--     b. Do teams that win the world series see a boost in attendance the following year? What about teams that made the playoffs? Making the playoffs means either being a division winner or a wild card winner.


-- 13. It is thought that since left-handed pitchers are more rare, causing batters to face them less often, that they are more effective. Investigate this claim and present evidence to either support or dispute this claim. First, determine just how rare left-handed pitchers are compared with right-handed pitchers. Are left-handed pitchers more likely to win the Cy Young Award? Are they more likely to make it into the hall of fame?
