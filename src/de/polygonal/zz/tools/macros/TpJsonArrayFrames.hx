/*
Copyright (c) 2014 Michael Baczynski, http://www.polygonal.de

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/
package de.polygonal.zz.tools.macros;

import de.polygonal.core.tools.FileSequence;
import haxe.ds.StringMap;
import haxe.io.Path;
import haxe.Json;
import haxe.macro.Context;
import haxe.macro.Expr;
import sys.FileSystem;

using Lambda;

class TpJsonArrayFrames
{
	macro public static function ofFileList(urls:Array<String>):Array<Field>
	{
		var p = Context.currentPos();
		var fields = Context.getBuildFields();
		
		if (urls.length == 0) Context.fatalError('no tp .json files found' , p);
		
		for (i in urls)
			if (!FileSystem.exists(i))
				Context.fatalError('file "$i" not found', p);
		
		var m = Context.getLocalClass().get().module;
		for (i in urls) Context.registerModuleDependency(m, i);
		
		build(urls, fields);
		return fields;
	}
	
	/**
		@param url e.g. ./res/sheet_multi_{n}.png
	**/
	macro public static function ofMultiPack(url:String):Array<Field>
	{
		var p = Context.currentPos();
		var fields = Context.getBuildFields();
		
		var path = new Path(url);
		
		//multipack index specified? e.g. spritesheet_sd_{n}.json
		var matchMultiPackIndex = ~/\{n\}/;
		if (matchMultiPackIndex.match(path.file))
			path.file = matchMultiPackIndex.replace(path.file, "(\\d)");
		else
			Context.fatalError('no multipack index ("{n}") found in "$url"', p);
		
		var urls = [];
		var ereg = new EReg(path.file, "");
		for (file in FileSystem.readDirectory(path.dir))
		{
			if (!~/\.(?:(json|bin)$/.match(file)) continue;
			if (!ereg.match(file)) continue;
			urls.push('${path.dir}/$file');
		}
		
		if (urls.length == 0) Context.fatalError('no tp .json files found' , p);
		
		build(urls, fields);
		return fields;
	}
	
	#if macro
	static function build(urls:Array<String>, output:Array<Field>)
	{
		var p = Context.currentPos();
		
		//read all tp json files and collect frames
		var frames:Array<Dynamic> = [];
		for (url in urls)
		{
			try 
			{
				var str:String;
				if (~/\.bin$/.match(url))
				{
					var bytes = sys.io.File.getBytes(url);
					str = de.polygonal.zz.texture.atlas.format.TpJsonArrayPacker.unpack(bytes);
				}
				else
					str = sys.io.File.getContent(url);
				
				var o:Dynamic = Json.parse(str);
				frames = frames.concat(Reflect.field(o, "frames"));
			}
			catch(error:Dynamic)
			{
				trace(error);
				Context.fatalError('malformed json file "$url"', p);
			}
		}
		
		//validate
		var map = new StringMap<Bool>();
		for (i in frames)
		{
			if (map.exists(i.filename))
				Context.fatalError('found duplicate frame ("${i.filename}")' , p);
			map.set(i.filename, true);
		}
		
		//generate sequences
		for (i in new FileSequence().find(frames.map(function(x) return x.filename).array()))
			output.push(makeArrayField("sequence_" + makeIdentifier(~/{counter}/.replace(i.name, "xxx")), i.items));
		
		//generate frames, but skip frames that are part of a sequence
		for (i in frames)
			output.push(makeStringConst("FRAME_" + makeIdentifier(i.filename).toUpperCase(), i.filename));
	}
	
	static function makeArrayField(name:String, values:Array<String>):Field
	{
		var a = [];
		for (i in values) a.push(macro $v{i});
		var f =
		{
			args: [],
			ret: TPath({name: "Array", pack: [], params: [TPType(TPath({name: "String", pack: [], params: [], sub: null}))], sub: null}),
			expr: macro return $a{a},
			params: []
		}
		return {name: name, doc: null, meta: [], access: [APublic, AStatic], kind: FFun(f), pos: Context.currentPos()};
	}
	
	static function makeStringConst(name:String, value:String):Field
	{
		var e = {expr: EConst(CString(value)), pos: Context.currentPos()};
		return {
			name: name, doc: null, meta: [], access: [APublic, AStatic, AInline],
			kind: FVar(TPath({pack: [], name: "String", params: [], sub: null}), e), pos: Context.currentPos()
		};
	}
	
	static function makeIdentifier(x:String) return ~/[^A-Za-z0-9]+/g.replace(x, "_");
	#end
}