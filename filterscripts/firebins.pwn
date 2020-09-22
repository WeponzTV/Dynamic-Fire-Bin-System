/* Dynamic Fire Bin System by Weponz (2018) */
#define FILTERSCRIPT
#include <a_samp>
#include <streamer>
#include <zcmd>

#define MAX_BINS 500//Default: 500 Max
#define DRAW_DIST 250//Default: 250 Metres

#define USE_STREAMER//Comment out to use CreateObject (Default: CreateDynamicObject)
#define USE_DATABASE//Comment out to prevent using SQLite to save/load bins. (Location: firebins.db)

#define LOG_CODE//Comment out to prevent object code from logging. (Location: firebins.txt)

#if defined USE_DATABASE
	new DB:database;
	new DBResult:result;
#endif

enum bin_data
{
	bin_db,
	bin_id,
	bin_fire,
	Float:bin_x,
	Float:bin_y,
	Float:bin_z,
	bool:bin_active
};
new BinData[MAX_BINS][bin_data];

stock IsPointInRangeOfPoint(Float:x, Float:y, Float:z, Float:x2, Float:y2, Float:z2, Float:range)
{
	x2 -= x;
	y2 -= y;
	z2 -= z;
	return ((x2 * x2) + (y2 * y2) + (z2 * z2)) < (range * range);
}

stock GetFreeBinSlot()
{
	for(new i = 0; i < MAX_BINS; i++)
	{
        if(BinData[i][bin_active] == false) return i;
	}
	return -1;
}

#if defined USE_DATABASE
	stock GetFreeDatabaseSlot()
	{
		for(new i = 0; i < MAX_BINS; i++)
		{
		    new query[128];
	        format(query, sizeof(query), "SELECT `ID` FROM `BINS` WHERE `ID` = '%d'", i);
	    	result = db_query(database, query);
	    	if(!db_num_rows(result))
	    	{
	    		db_free_result(result);
	    	    return i;
	    	}
	    	db_free_result(result);
		}
		return -1;
	}
#endif

stock CheckValidPos(Float:x, Float:y, Float:z)
{
	for(new i = 0; i < MAX_BINS; i++)
	{
        if(BinData[i][bin_active] == true)
        {
            if(IsPointInRangeOfPoint(x, y, z, BinData[i][bin_x], BinData[i][bin_y], BinData[i][bin_z], 2.0))
            {
                return 0;
            }
        }
	}
	return 1;
}

stock DeleteFireBin(binid)
{
	#if defined USE_STREAMER
	    if(IsValidDynamicObject(BinData[binid][bin_id])) { DestroyDynamicObject(BinData[binid][bin_id]); }
	    if(IsValidDynamicObject(BinData[binid][bin_fire])) { DestroyDynamicObject(BinData[binid][bin_fire]); }
	#else
	    if(IsValidObject(BinData[binid][bin_id])) { DestroyObject(BinData[binid][bin_id]); }
	    if(IsValidObject(BinData[binid][bin_fire])) { DestroyObject(BinData[binid][bin_fire]); }
	#endif

	BinData[binid][bin_active] = false;

	#if defined USE_DATABASE
	    new query[128];
	    format(query, sizeof(query), "DELETE FROM `BINS` WHERE `ID` = '%d'", BinData[binid][bin_db]);
		result = db_query(database, query);
		db_free_result(result);
	#endif
	return 1;
}

stock CreateFireBin(binid, Float:x, Float:y, Float:z)
{
    BinData[binid][bin_x] = x;
    BinData[binid][bin_y] = y;
    BinData[binid][bin_z] = z;

    BinData[binid][bin_active] = true;

	#if defined USE_STREAMER
    	BinData[binid][bin_id] = CreateDynamicObject(1362, x, y, z - 0.4, 0.0, 0.0, 0.0, -1, -1, -1, DRAW_DIST);//Bin
		BinData[binid][bin_fire] = CreateDynamicObject(3461, x, y, z - 1.4, 0.0, 0.0, 0.0, -1, -1, -1, DRAW_DIST);//Fire
	#else
		BinData[binid][bin_id] = CreateObject(1362, x, y, z - 0.4, 0.0, 0.0, 0.0, DRAW_DIST);//Bin
		BinData[binid][bin_fire] = CreateObject(3461, x, y, z - 1.4, 0.0, 0.0, 0.0, DRAW_DIST);//Fire
	#endif

	#if defined USE_DATABASE
	    new query[128], slot = GetFreeDatabaseSlot();
	    if(slot != -1)
	    {
			BinData[binid][bin_db] = slot;

			format(query, sizeof(query), "INSERT INTO `BINS` (`ID`, `X`, `Y`, `Z`) VALUES ('%d', '%f', '%f', '%f')", binid, x, y, z);
			result = db_query(database, query);
			db_free_result(result);
		}
	#endif

	#if defined LOG_CODE
	    new File:log = fopen("firebins.txt", io_append), string[400];
		if(log)
		{
			#if defined USE_STREAMER
			  	format(string, sizeof(string), "CreateDynamicObject(1362, %f, %f, %f - 0.4, 0.0, 0.0, 0.0, -1, -1, -1, %f);//Fire Bin %i (BIN)\r\nCreateDynamicObject(3461, %f, %f, %f - 1.4, 0.0, 0.0, 0.0, -1, -1, -1, %f);//Fire Bin %i (FIRE)\r\n", x, y, z, DRAW_DIST, (binid + 1), x, y, z, DRAW_DIST, (binid + 1));
				fwrite(log, string);
				fclose(log);
			#else
			  	format(string, sizeof(string), "CreateObject(1362, %f, %f, %f - 0.4, 0.0, 0.0, 0.0, %f);//Fire Bin %i (BIN)\r\nCreateObject(3461, %f, %f, %f - 1.4, 0.0, 0.0, 0.0, %f);//Fire Bin %i (FIRE)\r\n", x, y, z, DRAW_DIST, (binid + 1), x, y, z, DRAW_DIST, (binid + 1));
				fwrite(log, string);
				fclose(log);
			#endif
		}
	#endif
	return binid;
}

#if defined USE_DATABASE
	stock LoadFireBins()
	{
		new query[128], field[32];
		for(new i = 0; i < MAX_BINS; i++)
		{
		    format(query, sizeof(query), "SELECT * FROM `BINS` WHERE `ID` = '%d'", i);
		  	result = db_query(database, query);
		 	if(db_num_rows(result))
			{
				BinData[i][bin_active] = true;

				db_get_field_assoc(result, "ID", field, sizeof(field));
				BinData[i][bin_db] = strval(field);

				db_get_field_assoc(result, "X", field, sizeof(field));
				BinData[i][bin_x] = floatstr(field);

				db_get_field_assoc(result, "Y", field, sizeof(field));
				BinData[i][bin_y] = floatstr(field);

				db_get_field_assoc(result, "Z", field, sizeof(field));
				BinData[i][bin_z] = floatstr(field);

				#if defined USE_STREAMER
			    	BinData[i][bin_id] = CreateDynamicObject(1362, BinData[i][bin_x], BinData[i][bin_y], BinData[i][bin_z] - 0.4, 0.0, 0.0, 0.0, -1, -1, -1, DRAW_DIST);//Bin
					BinData[i][bin_fire] = CreateDynamicObject(3461, BinData[i][bin_x], BinData[i][bin_y], BinData[i][bin_z] - 1.4, 0.0, 0.0, 0.0, -1, -1, -1, DRAW_DIST);//Fire
				#else
					BinData[i][bin_id] = CreateObject(1362, BinData[i][bin_x], BinData[i][bin_y], BinData[i][bin_z] - 0.4, 0.0, 0.0, 0.0, DRAW_DIST);//Bin
					BinData[i][bin_fire] = CreateObject(3461, BinData[i][bin_x], BinData[i][bin_y], BinData[i][bin_z] - 1.4, 0.0, 0.0, 0.0, DRAW_DIST);//Fire
				#endif
			}
		}
		return 1;
	}
#endif

public OnFilterScriptInit()
{
	for(new i = 0; i < MAX_BINS; i++)
	{
	    BinData[i][bin_active] = false;
	}

	#if defined USE_DATABASE
    	database = db_open("firebins.db");
		db_query(database, "CREATE TABLE IF NOT EXISTS `BINS` (`ID`, `X`, `Y`, `Z`)");
		LoadFireBins();
	#endif
	return 1;
}

public OnFilterScriptExit()
{
	#if defined USE_DATABASE
    	db_close(database);
    #endif
	return 1;
}

CMD:deletebin(playerid, params[])
{
	if(!IsPlayerAdmin(playerid)) return SendClientMessage(playerid, -1, "SERVER: You must be logged into RCON to use this command.");
	for(new i = 0; i < MAX_BINS; i++)
	{
	    if(BinData[i][bin_active] == true)
	    {
	        if(IsPlayerInRangeOfPoint(playerid, 1.5, BinData[i][bin_x], BinData[i][bin_y], BinData[i][bin_z]))
	        {
	            return DeleteFireBin(i);
	        }
	    }
	}
	SendClientMessage(playerid, -1, "SERVER: You are currently not near any fire bins.");
	return 1;
}

CMD:createbin(playerid, params[])
{
	new Float:pos[3], slot = GetFreeBinSlot();
	GetPlayerPos(playerid, pos[0], pos[1], pos[2]);
	if(!IsPlayerAdmin(playerid)) return SendClientMessage(playerid, -1, "SERVER: You must be logged into RCON to use this command.");
	if(slot == -1) return SendClientMessage(playerid, -1, "SERVER: The server has reached the maximum aloud fire bins.");
	if(CheckValidPos(pos[0], pos[1], pos[2]) == 0) return SendClientMessage(playerid, -1, "SERVER: You cannot create a fire bin within 2 metres of any other fire bin.");
	CreateFireBin(slot, pos[0], pos[1], pos[2]);
	return 1;
}

