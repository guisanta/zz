package de.polygonal.zz.render.effect;

class ColorEffect extends Effect
{
	inline public static var TYPE = 2;
	
	public var color:Int;
	
	public function new(color:Int)
	{
		super(TYPE);
		
		this.color = color;
	}
	
	override public function draw(renderer:Renderer)
	{
		renderer.drawColorEffect(this);
	}
}