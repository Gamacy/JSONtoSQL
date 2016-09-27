
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


/*
UPDATES
9/7/16 - Sam: Adding some commentary
9/27/16 - Reilly: First Check-In to Git


*/
/*
JSON Schema:
[
    {
        "filterField": "title",
        "value": "deus ex"  --Single Values
    },
    {
        "filterField": "region",
        "value": [ --Arrays of values
            1,
            2
        ]
    }
]
*/
CREATE PROCEDURE [dbo].[JSONtoSQL] @json nvarchar(max) AS

--Drop temp table for formatted and parsed json if it exists
IF OBJECT_ID('tempdb.dbo.#filters', 'U') IS NOT NULL
DROP TABLE #filters;

--Insert parsed and formatted json filter into temp table
SELECT
[FilterField] AS [FilterField]
,MAX([Value]) AS [Value]
, '['+[FilterField] + '] IN ' + MAX([Value]) AS [Clause]

INTO #filters

FROM(
SELECT 
[FilterField]
,'(''' + [Value] + ''')' AS [Value] 
FROM OPENJSON(@json) 
WITH (filterField nvarchar(50) 'strict $.filterField',
		value nvarchar(50) '$.value')

--Union to mesh data from single item value fields and array value fields
UNION

SELECT 
[FilterField]
,REPLACE('(' + LEFT(RIGHT([value],LEN([value])-1),LEN([Value])-2) + ')','"','''') AS [Value]
FROM OPENJSON(@json) 
WITH (filterField nvarchar(50) '$.filterField',  
       --value nvarchar(50) '$.value',
	   [value] nvarchar(MAX) AS JSON)
) x
GROUP BY
[FilterField]

--Use temp table to build dynamic SQL query based on filters
DECLARE @cols nvarchar(max)

select @cols = STUFF((SELECT ' AND ' + col
                    from #filters
                    cross apply
                    (
                      select Clause
                    ) c (col)
                    group by col
            FOR XML PATH(''), TYPE
            ).value('.', 'NVARCHAR(MAX)') 
        ,1,1,'')

DECLARE @query nvarchar(max)

SELECT @query = 'SELECT * FROM [dbo].[SourceTable] WHERE 1=1 '+@cols

print @query

exec sp_executesql @query;





GO


