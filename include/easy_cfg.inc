#if !defined _ini_file_included
	#include <ini_file>
#endif

new stock cfg_path[64] = "plugins/easy_cfg.ini";

stock cfg_set_path(const path[])
{
	copy(cfg_path,charsmax(cfg_path),path);
}

stock cfg_get_path(path[], len)
{
	new szFile[64]; // as in ini_file
	formatex(szFile[get_configsdir(szFile,charsmax(szFile))], charsmax(szFile), "/%s.ini", cfg_path);
	copy(path,len,szFile);
}

stock cfg_read_str(const section[], const arg[], default_val[], out_val[], outlen)
{
	if (!ini_read_string(cfg_path, section, arg, out_val, outlen))
	{
		ini_write_string(cfg_path, section, arg, default_val);
		copy(out_val,outlen,default_val);
	}
}
stock cfg_read_int(const section[], const arg[], const default_val, &out_val)
{
	if (!ini_read_int(cfg_path, section, arg, out_val))
	{
		ini_write_int(cfg_path, section, arg, default_val);
		out_val = default_val;
	}
}
stock cfg_read_bool(const section[], const arg[], const bool:default_val, &bool:out_val)
{
	static tmp_bool[16];
	if (!ini_read_string(cfg_path, section, arg, tmp_bool, charsmax(tmp_bool)))
	{
		ini_write_string(cfg_path, section, arg, default_val ? "true" : "false");
		out_val = default_val;
	}
	else 
	{
		out_val = equali(tmp_bool,"true") != 0;
	}
}
stock cfg_read_flt(const section[], const arg[], const Float:default_val, &Float:out_val)
{
	if (!ini_read_float(cfg_path, section, arg, out_val))
	{
		ini_write_float(cfg_path, section, arg, default_val);
		out_val = default_val;
	}
}

stock cfg_write_str(const section[], const arg[], val[])
{
	ini_write_string(cfg_path, section, arg, val);
}
stock cfg_write_int(const section[], const arg[], const val)
{
	ini_write_int(cfg_path, section, arg, val);
}
stock cfg_write_bool(const section[], const arg[], const bool:val)
{
	ini_write_string(cfg_path, section, arg, val ? "true" : "false");
}
stock cfg_write_flt(const section[], const arg[], const Float:val)
{
	ini_write_float(cfg_path, section, arg, val);
}