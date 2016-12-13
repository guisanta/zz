package de.polygonal.zz.texture;

import de.polygonal.zz.data.*;
import de.polygonal.zz.render.*;
import de.polygonal.zz.render.effect.*;
import de.polygonal.zz.texture.*;
import de.polygonal.zz.texture.atlas.TextureAtlas;
import de.polygonal.zz.texture.atlas.TextureAtlasFormat;
import haxe.ds.IntMap;

class TextureLib
{
	public static var globalTextureScale = 1.;
	
	static var _renderer:Renderer;
	static var _textureLut = new IntMap<Texture>();
	
	public static function setRenderer(renderer:Renderer)
	{
		_renderer = renderer;
	}
	
	public static function allocateTexture(id:Int, image:ImageData, ?pma:Bool = true, ?format:TextureAtlasFormat):Texture
	{
		assert(_renderer != null);
		assert(!_textureLut.exists(id), 'texture [$id] was allocated before');
		
		var texture = new Texture();
		texture.isAlphaPremultiplied = pma;
		texture.setImageData(image, _renderer.supportsNonPowerOfTwoTextures);
		texture.scale = globalTextureScale;
		_textureLut.set(id, texture);
		if (format != null) texture.atlas = new TextureAtlas(texture, format.getAtlas());
		
		L.d('Allocated texture [$id]');
		return texture;
	}
	
	#if flash
	public static function allocateAtfTexture(id:Int, bytes:flash.utils.ByteArray, ?format:TextureAtlasFormat):Texture
	{
		assert(_renderer != null);
		assert(!_textureLut.exists(id), 'texture [$id] was allocated before');
		
		var texture = new Texture();
		texture.setAtfData(bytes);
		_textureLut.set(id, texture);
		if (format != null) texture.atlas = new TextureAtlas(texture, format.getAtlas());
		
		L.d('Allocated compressed texture [$id]');
		return texture;
	}
	#end
	
	public static function getTexture(id:Int):Texture
	{
		assert(_textureLut.exists(id), 'texture [$id] does not exist, call allocateTexture() first');
		return _textureLut.get(id);
	}
	
	public static function isTextureAllocated(id:Int):Bool
	{
		return _textureLut.exists(id);
	}
	
	public static function releaseTexture(id:Int)
	{
		assert(_textureLut.exists(id), 'texture [$id] does not exist');
		
		var texture = getTexture(id);
		_textureLut.remove(id);
		texture.free();
	}
}