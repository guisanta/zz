/*
Copyright (c) 2016 Michael Baczynski, http://www.polygonal.de

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

import de.polygonal.ds.tools.ArrayTools;
import de.polygonal.zz.data.ImageData;
import de.polygonal.zz.texture.atlas.TextureAtlasFormat.TextureAtlasDef;
import haxe.crypto.Base64;
import haxe.ds.StringMap;
import haxe.io.BytesInput;
import haxe.zip.InflateImpl;

using Std;

@:allow(de.polygonal.zz.tiled.TmxFile)
@:build(de.polygonal.zz.tools.macros.MakePublicVarsReadOnly.build())
@:publicFields
class TmxData
{
	var orientation:String;
	var width:Int;
	var height:Int;
	var tileWidth:Int;
	var tileHeight:Int;
	var tilesets:Array<TmxTileSet>;
	var properties:Map<String, Dynamic>;
	var layers:Array<TmxLayer>;
	function new() {}
}

@:allow(de.polygonal.zz.tiled.TmxFile)
@:build(de.polygonal.zz.tools.macros.MakePublicVarsReadOnly.build())
@:publicFields
class TmxTileSet
{
	var firstGid:Int;
	var name:String;
	var tileWidth:Int;
	var tileHeight:Int;
	var spacing:Int;
	var margin:Int;
	var tileCount:Int;
	var columns:Int;
	var image:TmxImage;
	var properties:Map<String, Dynamic>;
	var tiles:Array<TmxTile>;
	function new() {}
}

@:allow(de.polygonal.zz.tiled.TmxFile)
@:build(de.polygonal.zz.tools.macros.MakePublicVarsReadOnly.build())
@:publicFields
class TmxLayer
{
	var name:String;
	var data:Array<Int>;
	var properties:Map<String, Dynamic>;
	function new() {}
}

@:allow(de.polygonal.zz.tiled.TmxFile)
@:build(de.polygonal.zz.tools.macros.MakePublicVarsReadOnly.build())
@:publicFields
class TmxImage
{
	var source:String;
	var width:Int;
	var height:Int;
	function new() {}
}

@:allow(de.polygonal.zz.tiled.TmxFile)
@:build(de.polygonal.zz.tools.macros.MakePublicVarsReadOnly.build())
@:publicFields
class TmxTile
{
	var id:Int;
	var properties:Map<String, Dynamic>;
	function new() {}
}

/**
	TMX Map Format (TMX Map Format v1.0 generated with Tiled Map Editor v0.18.1)
	
	- see http://doc.mapeditor.org/reference/tmx-map-format/
	- the first tile in the tileset image (top-left corner) has to be empty (100% transparent).
**/
class TmxFile
{
	var mXmlString:String;
	var mData:TmxData;
	
	public function new(xmlString:String)
	{
		mXmlString = xmlString;
	}
	
	public function getData():TmxData
	{
		if (mData != null) return mData;
		
		var e = Xml.parse(mXmlString).firstElement();
		
		var o = new TmxData();
		o.orientation = e.get("orientation");
		o.width       = e.get("width").parseInt();
		o.height      = e.get("height").parseInt();
		o.tileWidth   = e.get("tilewidth").parseInt();
		o.tileHeight  = e.get("tileheight").parseInt();
		o.tilesets    = [];
		o.layers      = [];
		
		for (e in e.elements())
		{
			switch (e.nodeName)
			{
				case "properties":
					o.properties = new Map<String, Dynamic>();
					parseProperties(e, o.properties);
				
				case "tileset":
					o.tilesets.push(parseTileSet(e));
				
				case "layer":
					o.layers.push(parseLayer(e));
			}
		}
		return mData = o;
	}
	
	function parseTileSet(node:Xml):TmxTileSet
	{
		var o = new TmxTileSet();
		o.firstGid   = node.get("firstgid").parseInt();
		o.name       = node.get("name");
		o.tileWidth  = node.get("tilewidth").parseInt();
		o.tileHeight = node.get("tileheight").parseInt();
		o.spacing    = node.exists("spacing") ? node.get("spacing").parseInt() : 0;
		o.margin     = node.exists("margin") ? node.get("margin").parseInt() : 0;
		o.tileCount  = node.get("tilecount").parseInt();
		o.columns    = node.get("columns").parseInt();
		o.image      = null;
		o.tiles      = [];
		
		for (e in node.elements())
		{
			switch (e.nodeName)
			{
				case "properties":
					o.properties = new Map<String, Dynamic>();
					parseProperties(e, o.properties);
				
				case "image":
					var i = o.image = new TmxImage();
					i.source = e.get("source");
					i.width  = e.get("width").parseInt();
					i.height = e.get("height").parseInt();
				
				case "tile":
					var t = new TmxTile();
					t.id = e.get("id").parseInt();
					o.tiles.push(t);
					for (child in e.elements())
					{
						if (child.nodeName == "properties")
						{
							t.properties = new Map<String, Dynamic>();
							parseProperties(child, t.properties);
						}
					}
			}
		}
		return o;
	}
	
	function parseLayer(node:Xml):TmxLayer
	{
		var o = new TmxLayer();
		o.name = node.get("name");
		
		for (e in node.elements())
		{
			switch (e.nodeName)
			{
				case "properties":
					o.properties = new Map<String, Dynamic>();
					parseProperties(e, o.properties);
				
				case "data":
					var encoding = e.get("encoding");
					if (encoding == null)
					{
						var c;
						c = 0;
						for (i in node.firstElement().elements()) c++; o.data = ArrayTools.alloc(c);
						c = 0;
						for (i in node.firstElement().elements()) o.data[c++] = i.get("gid").parseInt();
					}
					else
					if (encoding == "csv")
					{
						var a = e.firstChild().nodeValue.split(",");
						var k = a.length;
						o.data = ArrayTools.alloc(k);
						for (i in 0...k) o.data[i] = a[i].parseInt();
					}
					else
					if (encoding == "base64")
					{
						var bytes = Base64.decode(StringTools.trim(e.firstChild().nodeValue));
						var input = new BytesInput(bytes);
						if (e.get("compression") == "zlib")
							input = new BytesInput(InflateImpl.run(input));
						else
						if (e.get("compression") == "gzip")
							throw "gzip compression is not supported";
						var k = input.length;
						o.data = ArrayTools.alloc(k >> 2);
						var i = 0;
						var j = 0;
						while (i < k)
						{
							o.data[j++] = input.readInt32();
							i += 4;
						}
					}
			}
		}
		return o;
	}
	
	function parseProperties(node:Xml, output:Map<String, Dynamic>)
	{
		for (e in node.elements())
		{
			var n = e.get("name");
			var v = e.get("value");
			var t = e.get("type");
			if (t != null)
			{
				output.set(n,
					switch (t)
					{
						case "bool": v == "true" ? true : false;
						case "color": Std.parseInt("0x" + v.substring(1));
						case "float": v.parseFloat();
						case "int": v.parseInt();
						case _: v;
					});
			}
			else
				output.set(n, v);
		}
	}
}