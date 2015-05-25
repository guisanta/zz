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
package de.polygonal.zz.tiled;

import de.polygonal.zz.data.ImageData;
import de.polygonal.zz.texture.atlas.TextureAtlasFormat.TextureAtlasDef;
import haxe.crypto.Base64;
import haxe.ds.StringMap;
import haxe.io.BytesInput;
import haxe.zip.InflateImpl;

using Std;

typedef TmxData =
{
	var orientation:String;
	var width:Int;
	var height:Int;
	var tileWidth:Int;
	var tileHeight:Int;
	var tilesets:Array<TmxTileSet>;
	var properties:Dynamic;
}

typedef TmxTileSet =
{
	var firstGid:Int;
	var name:String;
	var tileWidth:Int;
	var tileHeight:Int;
	var image:{source:String, trans:Int, width:Int, height:Int};
	var layers:Array<TmxLayer>;
	var properties:Array<Dynamic>;
	var spacing:Int;
	var margin:Int;
}

typedef TmxLayer =
{
	var name:String;
	var data:Array<Int>;
	var properties:Dynamic;
}

/**
	TMX Map Format
	
	- see https://github.com/bjorn/tiled/wiki/TMX-Map-Format
	- the first tile in the tileset image (top-left corner) has to be empty (100% transparent).
**/
class TmxFile
{
	var mStr:String;
	//var mTileSets:Array<{name:String, data:BitmapData}>;
	
	var mData:TmxData;
	
	public function new(xmlStr:String)//, tileSets:Array<{name:String, data:BitmapData}>) 
	{
		mStr = xmlStr;
		//mTileSets = tileSets;
	}
	
	public function getData():TmxData
	{
		if (mData != null) return mData;
		
		var e = Xml.parse(mStr).firstElement();
		
		var data =
		{
			orientation: e.get("orientation"),
			width: Std.parseInt(e.get("width")),
			height: Std.parseInt(e.get("height")),
			tileWidth: Std.parseInt(e.get("tilewidth")),
			tileHeight: Std.parseInt(e.get("tileheight")),
			tilesets: [],
			properties: {}
		};
		
		var tileSet = null;
		
		for (e in e.elements())
		{
			switch (e.nodeName)
			{
				case "properties":
					readProperties(e, data.properties);
				
				case "tileset":
					if (tileSet != null)
						data.tilesets.push(tileSet);
					tileSet = readTileSet(e);
				
				case "layer":
					var layer = readLayer(e);
					tileSet.layers.push(layer);
			}
		}
		
		if (tileSet != null)
			data.tilesets.push(tileSet);
			
		return mData = data;
	}
	
	function readTileSet(node:Xml):TmxTileSet
	{
		var image = {source: "", trans: 0, width: 0, height: 0};
		var properties = [];
		
		for (e in node.elements())
		{
			switch (e.nodeName)
			{
				case "image":
					image.source = e.get("source");
					image.trans = e.get("trans").parseInt();
					if (e.exists("width"))
						image.width = e.get("width").parseInt();
					if (e.exists("height"))
						image.height = e.get("height").parseInt();
				
				case "tile":
					var o = {};
					for (i in e.elements())
					{
						if (i.nodeName == "properties")
						{
							readProperties(i, o);
							properties[e.get("id").parseInt()] = o;
							break;
						}
					}
			}
		}
		
		return
		{
			firstGid: node.get("firstgid").parseInt(),
			name: node.get("name"),
			tileWidth: node.get("tilewidth").parseInt(),
			tileHeight: node.get("tileheight").parseInt(),
			image: image,
			layers: [],
			properties: properties,
			spacing: node.exists("spacing") ? node.get("spacing").parseInt() : 0,
			margin: node.exists("margin") ? node.get("margin").parseInt() : 0
		}
	}
	
	function readLayer(node:Xml):TmxLayer
	{
		var gids:Array<Int> = null;
		var properties = {};
		
		for (e in node.elements())
		{
			switch (e.nodeName)
			{
				case "properties":
					readProperties(e, properties);
				
				case "data":
					var encoding = e.get("encoding");
					if (encoding == null)
					{
						gids = [];
						for (i in node.firstElement().elements())
							gids.push(i.get("gid").parseInt());
					}
					else
					if (encoding == "csv")
					{
						gids = Lambda.array(Lambda.map(
							e.firstChild().nodeValue.split(","),
							function(x) return x.parseInt()));
					}
					else
					if (encoding == "base64")
					{
						gids = [];
						
						var bytes = Base64.decode(StringTools.trim(e.firstChild().nodeValue));
						var input = new BytesInput(bytes);
						
						if (e.get("compression") == "zlib")
							input = new BytesInput(InflateImpl.run(input));
						else
						if (e.get("compression") == "gzip")
							throw "gzip compression is not supported";
						
						gids = [];
						var i = 0;
						var k = input.length;
						while (i < k)
						{
							gids.push(input.readInt32());
							i += 4;
						}
					}
			}
		}
		
		return
		{
			name: node.get("name"),
			data: gids,
			properties: properties
		};
	}
	
	function readProperties(node:Xml, output:Dynamic)
	{
		for (e in node.elements())
			Reflect.setField(output, e.get("name"), e.get("value"));
	}
}