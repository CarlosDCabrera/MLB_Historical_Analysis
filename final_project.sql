-- PART I: SCHOOL ANALYSIS
-- 1. View the schools and school details tables
SELECT * 
FROM schools
ORDER BY yearID;

SELECT * 
FROM school_details;
-- 2. In each decade, how many schools were there that produced players?
SELECT FLOOR(yearID / 10) * 10 AS decade, COUNT(DISTINCT schoolID) AS num_schools
FROM schools
GROUP BY FLOOR(yearID / 10) * 10
ORDER BY FLOOR(yearID / 10) * 10;

-- 3. What are the names of the top 5 schools that produced the most players?
SELECT sd.name_full, COUNT(DISTINCT s.playerID) AS num_players
FROM schools s INNER JOIN school_details sd ON s.schoolID = sd.schoolID
GROUP BY sd.name_full
ORDER BY COUNT(DISTINCT s.playerID) DESC LIMIT 5;

-- 4. For each decade, what were the names of the top 3 schools that produced the most players?
WITH d AS (SELECT FLOOR(s.yearID / 10) * 10 AS decade, sd.name_full, COUNT(DISTINCT s.playerID) AS num_players
			FROM schools s INNER JOIN school_details sd ON s.schoolID = sd.schoolID
			GROUP BY FLOOR(s.yearID / 10) * 10, sd.name_full),

     dRank AS (SELECT decade, name_full, num_players, ROW_NUMBER() OVER(partition by decade ORDER BY num_players DESC) AS row_rank
				FROM d)
                
SELECT decade, name_full, num_players
FROM dRank
WHERE row_rank <= 3
ORDER BY decade DESC, num_players DESC;

-- PART II: SALARY ANALYSIS
-- 1. View the salaries table
SELECT * 
FROM salaries;

-- 2. Return the top 20% of teams in terms of average annual spending
WITH ts AS (SELECT teamID, yearID, SUM(salary) AS total_spend
				FROM salaries
				GROUP BY teamID, yearID),
	average_spend AS (SELECT teamID, AVG(total_spend) AS avg_spend
						FROM ts
						GROUP BY teamID),
	tiles AS (SELECT teamID, avg_spend, 
		NTILE(5) OVER(ORDER BY avg_spend DESC) AS percentile
		FROM average_spend)

SELECT teamID, ROUND(avg_spend / 1000000, 1) AS avg_spend_millions
FROM tiles
WHERE percentile = 1;

-- 3. For each team, show the cumulative sum of spending over the years
WITH cs AS (SELECT DISTINCT yearID, teamID, SUM(salary) OVER(PARTITION BY teamID ORDER BY teamID, yearID) AS cumulative_sum
			FROM salaries
			ORDER BY teamID, yearID)
            
SELECT DISTINCT yearID, teamID, ROUND(cumulative_sum / 1000000, 1) AS cumulative_sum_millions
FROM cs;

-- 4. Return the first year that each team's cumulative spending surpassed 1 billion
WITH cs AS (SELECT DISTINCT yearID, teamID, SUM(salary) OVER(PARTITION BY teamID ORDER BY teamID, yearID) AS cumulative_sum
			FROM salaries
			ORDER BY teamID, yearID),
	cum_sum AS (SELECT DISTINCT yearID, teamID, ROUND(cumulative_sum / 1000000, 1) AS cumulative_sum_millions
				FROM cs),
	row_num AS (SELECT DISTINCT yearID, teamID, cumulative_sum_millions, 
		ROW_NUMBER() OVER(partition by teamID ORDER BY cumulative_sum_millions) AS rn
		FROM cum_sum
        WHERE cumulative_sum_millions > 1000)

SELECT yearID, teamID, ROUND(cumulative_sum_millions / 1000, 2) AS cumulative_sum_billions
FROM row_num
WHERE rn = 1;

-- PART III: PLAYER CAREER ANALYSIS
-- 1. View the players table and find the number of players in the table
SELECT *
FROM players;

SELECT * 
FROM salaries;

SELECT COUNT(playerID) AS num_players
FROM players;

-- 2. For each player, calculate their age at their first game, their last game, and their career length (all in years). Sort from longest career to shortest career.
WITH cd AS (SELECT nameGiven, debut, finalgame, 
					CAST(CONCAT(birthYear, '-', birthMonth, '-', birthDay) AS DATE) AS combined_date
			FROM players)

SELECT nameGiven,
		FLOOR(DATEDIFF(debut, combined_date) / 365.25) AS starting_age,
        FLOOR(DATEDIFF(finalgame, combined_date) / 365.25) AS ending_age,
        FLOOR(DATEDIFF(finalgame, debut) / 365.25) AS career_length,
        TIMESTAMPDIFF(YEAR, debut, finalgame) AS carrer_length2
FROM cd
ORDER BY DATEDIFF(finalgame, debut) / 365.25 DESC;


-- 3. What team did each player play on for their starting and ending years?
WITH st AS (SELECT p.playerID, p.nameGiven, p.finalgame, s.teamID AS starting_team,
					YEAR(p.debut) AS starting_year,
					YEAR(p.finalgame) AS ending_year
			FROM players p INNER JOIN salaries s ON p.playerID = s.playerID AND s.yearID = YEAR(p.debut))

SELECT nameGiven, starting_year, starting_team, ending_year, s.teamID AS ending_team 
FROM st INNER JOIN salaries s ON st.playerID = s.playerID AND s.yearID = YEAR(st.finalgame)
ORDER BY starting_team, starting_year;

-- FLOOR(DATEDIFF(ending_year, starting_year)) >= 10
-- 4. How many players started and ended on the same team and also played for over a decade?
WITH st AS (SELECT p.playerID, p.nameGiven, p.finalgame, s.teamID AS starting_team,
					YEAR(p.debut) AS starting_year,
					YEAR(p.finalgame) AS ending_year
			FROM players p INNER JOIN salaries s ON p.playerID = s.playerID AND s.yearID = YEAR(p.debut))

SELECT nameGiven, starting_year, starting_team, ending_year, s.teamID AS ending_team 
FROM st INNER JOIN salaries s ON st.playerID = s.playerID AND s.yearID = YEAR(st.finalgame)
WHERE starting_team = s.teamID AND ending_year - starting_year > 10
ORDER BY starting_team, starting_year;

-- PART IV: PLAYER COMPARISON ANALYSIS
-- 1. View the players table
SELECT *
FROM players;

-- 2. Which players have the same birthday?
WITH b AS (SELECT nameGiven, CAST(CONCAT(birthYear, '-', birthMonth, '-', birthDay) AS DATE) AS birth_date
			FROM players)
            
SELECT birth_date, GROUP_CONCAT(nameGiven SEPARATOR ", ") AS players
FROM b
GROUP BY birth_date;

-- 3. Create a summary table that shows for each team, what percent of players bat right, left and both
WITH player_bats AS (SELECT playerID, bats
					FROM players),
	team_player_bats AS (SELECT s.teamID, s.playerID, p.bats
							FROM salaries s LEFT JOIN player_bats p ON s.playerID = p.playerID),
    bats_columns AS (SELECT teamID, playerID,
							CASE WHEN bats = "R" THEN 1 ELSE 0 END AS bats_right,
							CASE WHEN bats = "L" THEN 1 ELSE 0 END AS bats_left,
							CASE WHEN bats = "B" THEN 1 ELSE 0 END AS bats_both
					FROM team_player_bats)
SELECT teamID, COUNT(playerID) AS all_players, 
		ROUND(SUM(bats_right) / COUNT(playerID) * 100, 1) AS right_percent,
        ROUND(SUM(bats_left) / COUNT(playerID) * 100, 1) AS left_percent, 
        ROUND(SUM(bats_both) / COUNT(playerID) * 100, 1) AS both_percent
FROM bats_columns
GROUP BY teamID
ORDER BY teamID;

-- 4. How have average height and weight at debut game changed over the years, and what's the decade-over-decade difference?
WITH avgs AS (SELECT FLOOR(YEAR(debut) / 10) * 10 AS decade,
					AVG(weight) AS avg_weight,
					AVG(height) AS avg_height
				FROM players
                GROUP BY FLOOR(YEAR(debut) / 10) * 10)
SELECT decade,
        avg_height - LAG(avg_height) OVER(ORDER BY decade) AS height_diff,
        avg_weight - LAG(avg_weight) OVER(ORDER BY decade) AS weight_diff
FROM avgs
WHERE decade IS NOT NULL;
