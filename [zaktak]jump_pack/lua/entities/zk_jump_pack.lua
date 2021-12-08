AddCSLuaFile()

DEFINE_BASECLASS( "base_jump_pack" )

ENT.Spawnable = true
ENT.PrintName = "Jump Pack"
ENT.Category  = "Zaktak's"


--[[-------------------------
: Config Below
---------------------------]]

local Gravity = 1
local JumpHeight = 400

--[[-------------------------
: End of Config
---------------------------]]

local zk_jump_color = Color(180, 180, 180)

if SERVER then
	resource.AddFile( "materials/entities/sent_jetpack.png" )
end

if CLIENT then
	ENT.MatHeatWave		= Material( "sprites/heatwave" )
	ENT.MatFire			= Material( "effects/fire_cloud1" )
	
	AccessorFunc( ENT , "WingClosure" , "WingClosure" )
	AccessorFunc( ENT , "WingClosureStartTime" , "WingClosureStartTime" )
	AccessorFunc( ENT , "WingClosureEndTime" , "WingClosureEndTime" )
	AccessorFunc( ENT , "NextParticle" , "NextParticle" )
	AccessorFunc( ENT , "LastActive" , "LastActive" )
	AccessorFunc( ENT , "LastFlameTrace" , "LastFlameTrace" )
	AccessorFunc( ENT , "NextFlameTrace" , "NextFlameTrace" )
	
	ENT.MaxEffectsSize = 0.25
	ENT.MinEffectsSize = 0.1
	
	ENT.JetpackWings = {
		Scale = 0.4,
		Model = Model( "models/xqm/jettailpiece1.mdl" ),
		Offsets = {
			{
				OffsetVec = Vector( 0 , -9 , 1.2 ),
				OffsetAng = Angle( 0 , 0 , 90 ),
			},
			{
				OffsetVec = Vector( 0 , 10 , 1.2 ),
				OffsetAng = Angle( 180 , 0 , -90 ),
			},
		}
	}
	
	ENT.JetpackFireBlue = Color( 0 , 0 , 255 , 128 )
	ENT.JetpackFireWhite = Color( 255 , 255 , 255 , 128 )
	ENT.JetpackFireNone = Color( 255 , 255 , 255 , 0 )
	ENT.JetpackFireRed = Color( 255 , 128 , 128 , 255 )
	
else
	
	ENT.StandaloneApeShitAngular = Vector( 0 , 10 , 10 )	--do a corkscrew
	ENT.StandaloneApeShitLinear = Vector( 0 , 0 , 0 )
	
	ENT.StandaloneAngular = vector_origin
	ENT.StandaloneLinear = Vector( 0 , 0 , 0 )
	
	ENT.ShowPickupNotice = true
	ENT.SpawnOnGroundConVar = CreateConVar( 
		"sv_spawnjumppackonground" , 
		"1", 
		{ 
			FCVAR_SERVER_CAN_EXECUTE, 
			FCVAR_ARCHIVE 
		}, 
		"When true, it will spawn the jumppack on the ground, otherwise it will try equipping it right away, if you already have one equipped it will not do anything" 
	)
end

--use this to calculate the position on the parent because I can't be arsed to deal with source's parenting bullshit with local angles and position
--plus this is also called during that parenting position recompute, so it's perfect

ENT.AttachmentInfo = {
	BoneName = "ValveBiped.Bip01_Spine2",
	OffsetVec = Vector( 3 , -5.6 , 0 ),
	OffsetAng = Angle( 180 , 90 , -90 ),
}

sound.Add( {
	name = "jetpack.thruster_loop",
	channel = CHAN_ITEM,
	volume = 1.0,
	level = 75,
	sound = "^thrusters/jet02.wav"
})

local sv_gravity = GetConVar "sv_gravity"

function ENT:SpawnFunction( ply, tr, ClassName )

	if not tr.Hit then return end

	local SpawnPos = tr.HitPos + tr.HitNormal * 36

	local ent = ents.Create( ClassName )
	ent:SetSlotName( ClassName )	--this is the best place to set the slot, only modify it ingame when it's not equipped
	ent:SetPos( SpawnPos )
	ent:SetAngles( Angle( 0 , 0 , 180 ) )
	ent:Spawn()
	
	--try equipping it, if we can't we'll just remove it
	if not self.SpawnOnGroundConVar:GetBool() then
		--forced should not be set here, as we still kinda want the equip logic to work as normal
		if not ent:Attach( ply , false ) then
			ent:Remove()
			return
		end
	end
	
	return ent

end

function ENT:Initialize()
	BaseClass.Initialize( self )
	if SERVER then
		self:SetModel( "models/thrusters/jetpack.mdl" )
		self:InitPhysics()
		
		self:SetMaxHealth( 100 )
		self:SetHealth( self:GetMaxHealth() )
		
		self:SetInfiniteFuel( true )
		self:SetMaxFuel( 100 )
		self:SetFuel( self:GetMaxFuel() )
		self:SetFuelDrain( 60 )	--drain in seconds
		self:SetFuelRecharge( 20 )	--recharge in seconds
		self:SetActive( false )
		self:SetGoneApeshit( math.random( 0 , 100 ) > 101 ) --little chance that on spawn we're gonna be crazy!
		self:SetGoneApeshitTime( 0 )
		
		self:SetCanStomp( false )
		self:SetDoGroundSlam( false )
		self:SetAirResistance( 2.5 )
		self:SetRemoveGravity( false )
		self:SetJetpackSpeed( 224 )
		self:SetJetpackStrafeSpeed( 600 )
		self:SetJetpackVelocity( 1200 )
		self:SetJetpackStrafeVelocity( 1200 )
	else
		self:SetLastActive( false )
		self:SetWingClosure( 0 )
		self:SetWingClosureStartTime( 0 )
		self:SetWingClosureEndTime( 0 )
		self:SetNextParticle( 0 )
		self:SetNextFlameTrace( 0 )
		self:SetLastFlameTrace( nil )
	end
end

function ENT:SetupDataTables()
	BaseClass.SetupDataTables( self )

	self:DefineNWVar( "Bool" , "Active" )
	self:DefineNWVar( "Bool" , "GoneApeshit" , true )	--set either when the owner dies with us active, or when we're being shot at
	self:DefineNWVar( "Bool" , "RemoveGravity" )
	self:DefineNWVar( "Bool" , "InfiniteFuel" , true , "Infinite Fuel" )
	self:DefineNWVar( "Bool" , "DoGroundSlam" )
	self:DefineNWVar( "Bool" , "CanStomp" , true , "Can stomp" )
	
	self:DefineNWVar( "Float" , "Fuel" )
	self:DefineNWVar( "Float" , "MaxFuel" )	--don't modify the max amount, the drain scales anyway, set to -1 to disable the fuel drain
	self:DefineNWVar( "Float" , "FuelDrain" , true , "Seconds to drain fuel" , 1 , 60 ) --how many seconds it's gonna take to drain all the fuel
	self:DefineNWVar( "Float" , "FuelRecharge" , true , "Seconds to recharge the fuel" , 1 , 60 ) --how many seconds it should take to fully recharge this
	self:DefineNWVar( "Float" , "AirResistance" , true , "Air Resistance" , 0 , 10 )
	self:DefineNWVar( "Float" , "GoneApeshitTime" ) --only used if infinite fuel is on
	
	self:DefineNWVar( "Int" , "Key" )	--override it to disallow people from editing the key since it's unused
	self:DefineNWVar( "Int" , "JetpackSpeed" , true , "Jetpack idle upward speed" , 1 , 1000 )
	self:DefineNWVar( "Int" , "JetpackStrafeSpeed" , true , "Jetpack idle side speed" , 1 , 1000 )
	self:DefineNWVar( "Int" , "JetpackVelocity" , true , "Jetpack active upward speed" , 1 , 3000 )
	self:DefineNWVar( "Int" , "JetpackStrafeVelocity" , true , "Jetpack active side speed" , 1 , 3000 )
	
end

function ENT:HandleFly( predicted , owner , movedata , usercmd )
	self:SetActive( self:CanFly( owner , movedata ) )
	
	--the check below has to be done with prediction on the client!
	
	if CLIENT and not predicted then
		return
	end
	
	--fixes a bug where if you set goneapeshit manually via the contextmenu and the physobj is asleep it wouldn't apply the simulated forces
	if SERVER and not predicted and self:GetGoneApeshit() then
		local physobj = self:GetPhysicsObject()
		if IsValid( physobj ) and physobj:IsAsleep() then
			physobj:Wake()
		end
	end
end

function ENT:HandleFuel( predicted )

	--like with normal rules of prediction, we don't want to run on the client if we're not in the simulation

	if not predicted and CLIENT then
		return
	end

	--we set the think rate on the entity to the tickrate on the server, we could've done NextThink() - CurTime(), but it's only a setter, not a getter
	local ft = engine.TickInterval()

	--screw that, during prediction we need to recharge with FrameTime()
	if predicted then
		ft = FrameTime()
	end

	local fueltime = self:GetActive() and self:GetFuelDrain() or self:GetFuelRecharge()

	local fuelrate = self:GetMaxFuel() / ( fueltime / ft )

	if self:GetActive() then
		fuelrate = fuelrate * -1

		if self:GetGoneApeshit() then
			--drain twice as much fuel if we're going craaaazy
			fuelrate = fuelrate * 2
		end
		
		--don't drain any fuel when infinite fuel is on, but still allow recharge
		if self:GetInfiniteFuel() then
			fuelrate = 0
		end
	else
		--recharge in different ways if we have an owner or not, because players might drop and reequip the jetpack to exploit the recharging
		if IsValid( self:GetControllingPlayer() ) then
			--can't recharge until our owner is on the ground!
			--prevents the player from tapping the jump button to fly and recharge at the same time
			if not self:GetControllingPlayer():OnGround() then
				fuelrate = 0
			end
		else
			--only recharge if our physobj is sleeping and it's valid ( should never be invalid in the first place )
			local physobj = self:GetPhysicsObject()
			if not IsValid( physobj ) or not physobj:IsAsleep() then
				fuelrate = 0
			end
		end
	end
	
	--holy shit, optimization??
	if fuelrate ~= 0 then	
		self:SetFuel( math.Clamp( self:GetFuel() + fuelrate , 0 , self:GetMaxFuel() ) )
	end
	
	--we exhausted all of our fuel, chill out if we're crazy
	if not self:HasFuel() and self:GetGoneApeshit() then
		self:SetGoneApeshit( false )
	end
end

function ENT:HandleLoopingSounds()

	--create the soundpatch if it doesn't exist, it might happen on the client sometimes since it's garbage collected

	if not self.JetpackSound then
		self.JetpackSound = CreateSound( self, "jetpack.thruster_loop" )
	end

	if self:GetActive() then
		local pitch = 125
		
		if self:GetGoneApeshit() then
			pitch = 175
		end
		
		self.JetpackSound:PlayEx( 0.5  , pitch )
	else
		self.JetpackSound:FadeOut( 0.1 )
	end
end

function ENT:HasFuel()
	return self:GetFuel() > 0
end

function ENT:GetFuelFraction()
	return self:GetFuel() / self:GetMaxFuel()
end

function ENT:CanFly( owner , mv )
	
	
	if IsValid( owner ) then
		return ( mv:KeyDown( IN_JUMP ) and mv:KeyDown( IN_DUCK ) ) and owner:OnGround() and owner:WaterLevel() == 0 and owner:GetMoveType() == MOVETYPE_WALK and owner:Alive() and (owner.JumpPackUsed == false or owner.JumpPackUsed == nil)
	end

	return false
end

function ENT:Think()

	--still act if we're not being held by a player
	if not self:IsCarried() then
		self:HandleFly( false )
		self:HandleFuel( false )
	end

	--animation related stuff should be fine to call here

	if CLIENT then
		self:HandleWings()
	end

	return BaseClass.Think( self )
end



function ENT:PredictedSetupMove( owner , mv , usercmd )
	
	self:HandleFly( true , owner , mv , usercmd )
	self:HandleFuel( true )

	if self:GetActive() then
		if ( mv:KeyDown( IN_JUMP ) and mv:KeyDown( IN_DUCK ) and (owner.JumpPackUsed == false or owner.JumpPackUsed == nil) ) then
			self:EmitPESound( "npc/scanner/cbot_energyexplosion1.wav" , nil , nil , nil , nil , true )
			local vel = owner:GetAimVector() * 400 + Vector( 0, 0, JumpHeight )
			mv:SetVelocity( vel )

			mv:SetForwardSpeed( 0 )
			mv:SetSideSpeed( 0 )
			mv:SetUpSpeed( 0 )

			local vPoint = owner:WorldSpaceCenter()
			local effectdata = EffectData()
			effectdata:SetOrigin( vPoint )
			effectdata:SetEntity( owner )
			effectdata:SetScale( 10 )
			util.Effect( "jump_pack_pop", effectdata )

			owner.JumpPackUsed = true
			timer.Simple( 3, function()
				owner.JumpPackUsed = false
			end )
		end
	end
end

function ENT:PredictedThink( owner , movedata )
end

function ENT:PredictedMove( owner , data )
	if self:GetActive() and self:GetGoneApeshit() then
		owner:SetGroundEntity( NULL )
	end
end

function ENT:PredictedFinishMove( owner , movedata )
	--[[
	if self:GetActive() then
		
		--
		-- Remove gravity when velocity is supposed to be zero for hover mode
		--
		if self:GetRemoveGravity() then
			local vel = movedata:GetVelocity()

			vel.z = vel.z + sv_gravity:GetFloat() * 0.5 * FrameTime()

			movedata:SetVelocity( vel )

			self:SetRemoveGravity( false )
		end
		
	end
	--]]
end

local	SF_PHYSEXPLOSION_NODAMAGE			=	0x0001
local	SF_PHYSEXPLOSION_PUSH_PLAYER		=	0x0002
local	SF_PHYSEXPLOSION_RADIAL				=	0x0004
local	SF_PHYSEXPLOSION_TEST_LOS			=	0x0008
local	SF_PHYSEXPLOSION_DISORIENT_PLAYER	=	0x0010

function ENT:PredictedHitGround( ply , inwater , onfloater , speed )
	if ( speed > 600 ) then
		local vPoint = ply:GetPos()
		local effectdata = EffectData()
		effectdata:SetOrigin( vPoint )
		effectdata:SetEntity( ply )
		effectdata:SetScale( 100 )
		effectdata:SetScale( 50 )
		util.Effect( "ThumperDust", effectdata )
		self:EmitPESound( "ambient/machines/thumper_dust.wav" , nil , nil , nil , nil , true )
	end
	return true
end

if SERVER then
	
	function ENT:OnTakeDamage( dmginfo )
		--we're already dead , might happen if multiple jetpacks explode at the same time
		if self:Health() <= 0 then
			return
		end
		
		self:TakePhysicsDamage( dmginfo )
		
		local oldhealth = self:Health()
		
		local newhealth = math.Clamp( self:Health() - dmginfo:GetDamage() , 0 , self:GetMaxHealth() )
		self:SetHealth( newhealth )
		
		if self:Health() <= 0 then
			--maybe something is relaying damage to the jetpack instead, an explosion maybe?
			if IsValid( self:GetControllingPlayer() ) then
				self:Drop( true )
			end
			self:Detonate( dmginfo:GetAttacker() )
			return
		end
		
		--roll a random, if we're not being held by a player and the random succeeds, go apeshit
		if dmginfo:GetDamage() > 3 and not self:GetGoneApeshit() then
			local rand = math.random( 1 , 10 )
			if rand <= 2 then
				if IsValid( self:GetControllingPlayer() ) then
					self:Drop( true )
				end
				self:SetGoneApeshit( true )
			end
		end
	end
	
	function ENT:OnAttach( ply )
		self:SetModelScale(.8)
		self:SetDoGroundSlam( false )
		--self:SetSolid( SOLID_BBOX )	--we can still be hit when on the player's back
	end
	
	function ENT:CanAttach( ply )
		if self:GetGoneApeshit() then
			return false
		end
	end

	function ENT:OnDrop( ply , forced )
		if IsValid( ply ) and not ply:Alive() then
			--when the player dies while still using us, keep us active and let us fly with physics until
			--our fuel runs out
			if self:GetActive() then
				self:SetGoneApeshit( true )
			end
		else
			self:SetActive( false )
		end
		--closeFuelTankDerma(ply)
	end

	function ENT:OnInitPhysics( physobj )
		if IsValid( physobj ) then
			physobj:SetMass( 75 )
			self:StartMotionController()
		end
		self:SetCollisionGroup( COLLISION_GROUP_NONE )
		--self:SetCollisionGroup( COLLISION_GROUP_WEAPON )	--set to COLLISION_GROUP_NONE to reenable collisions against players and npcs
	end
	
	function ENT:OnRemovePhysics( physobj )
		self:StopMotionController()
		self:SetCollisionGroup( COLLISION_GROUP_DEBRIS_TRIGGER )
		--self:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
	end
	
	function ENT:PhysicsSimulate( physobj , delta )
		
		--no point in applying forces and stuff if something is holding our physobj
		
		if self:GetActive() and not self:GetBeingHeld() then
			physobj:Wake()
			local force = self.StandaloneLinear
			local angular = self.StandaloneAngular
			
			if self:GetGoneApeshit() then
				force = self.StandaloneApeShitLinear
				angular = self.StandaloneApeShitAngular
			end
			
			--yes I know we're technically modifying the variable stored in ENT.StandaloneApeShitLinear and that it might fuck up other jetpacks
			--but it won't because we're simply using it as a cached vector_origin and overriding the z anyway
			force.z = -self:GetJetpackVelocity()
			
			return angular * physobj:GetMass() , force * physobj:GetMass() , SIM_LOCAL_FORCE
		end
	end
	
	function ENT:PhysicsCollide( data , physobj )
		--taken straight from valve's code, it's needed since garry overwrote VPhysicsCollision, friction sound is still there though
		--because he didn't override the VPhysicsFriction
		if data.DeltaTime >= 0.05 and data.Speed >= 70 then
			local volume = data.Speed * data.Speed * ( 1 / ( 320 * 320 ) )
			if volume > 1 then
				volume = 1
			end
			
			--TODO: find a better impact sound for this model
			self:EmitSound( "SolidMetal.ImpactHard" , nil , nil , volume , CHAN_BODY )
		end
		
		if self:CheckDetonate( data , physobj ) then
			self:Detonate()
		end
	end
	
	--can't explode on impact if we're not active
	function ENT:CheckDetonate( data , physobj )
		return self:GetActive() and data.Speed > 500 and not self:GetBeingHeld()
	end
	
	function ENT:Detonate( attacker )
		--you never know!
		if self:IsEFlagSet( EFL_KILLME ) then 
			return 
		end
		
		self:Remove()
		
		local fuel = self:GetFuel()
		local atk = IsValid( attacker ) and attacker or self
		
		--check how much fuel was left when we impacted
		local dmg = 1.5 * fuel
		local radius = 2.5 * fuel
		
		util.BlastDamage( self , atk , self:GetPos() , radius , dmg )
		util.ScreenShake( self:GetPos() , 1.5 , dmg , 0.25 , radius * 2 )
		
		local effect = EffectData()
		effect:SetOrigin( self:GetPos() )
		effect:SetMagnitude( dmg )	--this is actually the force of the explosion
		effect:SetFlags( bit.bor( 0x80 , 0x20 ) ) --NOFIREBALLSMOKE, ROTATE
		util.Effect( "Explosion" , effect )
	end
	
	
	function ENT:CanPlayerEditVariable( ply , key , val , editor )
		--don't modify values if we're active, dropped or not
		if self:GetActive() and key ~= "Key" then
			return false
		end
		
		--can't enable stomping, infinite fuel or goneapeshit if the player editing us isn't admin
		if ( key == "CanStomp" or key == "InfiniteFuel" or key == "GoneApeshit" ) and not ply:IsAdmin() then
			return false
		end
	end
	
else

	function ENT:Draw( flags )
		local pos , ang = self:GetCustomParentOrigin()
		
		--even though the calcabsoluteposition hook should already prevent this, it doesn't on other players
		--might as well not give it the benefit of the doubt in the first place
		if pos and ang then
			self:SetPos( pos )
			self:SetAngles( ang )
			self:SetupBones()
		end
		
		self:DrawModel( flags )
		
		self:DrawWings( flags )
		
		local atchpos , atchang = self:GetEffectsOffset()
		
		local effectsscale = self:GetEffectsScale()
		
		--technically we shouldn't draw the fire from here, it should be done in drawtranslucent
		--but since we draw from the player and he's not translucent this won't get called despite us being translucent
		--might as well just set us to opaque
		
		if self:GetActive() then	-- and bit.band( flags , STUDIO_TRANSPARENCY ) ~= 0 then
			self:DrawJetpackFire( atchpos , atchang , effectsscale )
		end
		
		self:DrawJetpackSmoke( atchpos , atchang , effectsscale )
	end
	
	--the less fuel we have, the smaller our particles will be
	function ENT:GetEffectsScale()
		return Lerp( self:GetFuel() / self:GetMaxFuel() , self.MinEffectsSize , self.MaxEffectsSize )
	end
	
	function ENT:GetEffectsOffset()
		local angup = self:GetAngles():Up()
		return self:GetPos() + angup * 10 , angup
	end
	
	function ENT:CreateWing()
		local wing = ClientsideModel( self.JetpackWings.Model )
		wing:SetModelScale( self.JetpackWings.Scale , 0 )
		wing:SetNoDraw( true )
		return wing
	end
	
	function ENT:HandleWings()
	
		if not IsValid( self.Wing ) then
			self.Wing = self:CreateWing()
		end

		if self:GetLastActive() ~= self:GetActive() then
			self:SetWingClosureStartTime( UnPredictedCurTime() )
			self:SetWingClosureEndTime( UnPredictedCurTime() + 3 )
			self:SetLastActive( self:GetActive() )
		end
		
		--do the math time fraction from the closure time to the UnPredictedCurTime,
		--and set everything on the wingclosure so that we can use it on a Lerp later during the draw
		if self:GetWingClosureStartTime() ~= 0 and self:GetWingClosureEndTime() ~= 0 then
			local starttime = self:GetWingClosureStartTime()
			local endtime = self:GetWingClosureEndTime()
			
			if not self:GetActive() then
				starttime , endtime = endtime , starttime
			end
			
			self:SetWingClosure( math.TimeFraction( starttime , endtime , UnPredictedCurTime() ) )
			
			--we're done here, stop calculating the closure
			if self:GetWingClosureEndTime() < UnPredictedCurTime() then
				self:SetWingClosureStartTime( 0 )
				self:SetWingClosureEndTime( 0 )
			end
		end
	end
	
	function ENT:DrawWings( flags )
		
		--it's safe to call these, since setupbones is called up above, we don't want to call that too many times
		local pos = self:GetPos()
		local ang = self:GetAngles()

		self.WingMatrix = Matrix()
		--TODO: reset the scale to Vector( 1 , 1 , 1 ) instead of recreating the matrix every frame
		local dist = Lerp( self:GetWingClosure() , -15 , 0 )
		self.WingMatrix:SetTranslation( Vector( 0 ,0 , dist ) )	--how far inside the jetpack we should go to hide our scaled down wings
		self.WingMatrix:Scale( Vector( 1 , 1 , self:GetWingClosure() ) ) --our scale depends on the wing closure
		
		if IsValid( self.Wing ) then
		
			self.Wing:EnableMatrix( "RenderMultiply" , self.WingMatrix )
			
			for i , v in pairs( self.JetpackWings.Offsets ) do
				local gpos , gang = LocalToWorld( v.OffsetVec , v.OffsetAng , pos , ang )
				self.Wing:SetPos( gpos )
				self.Wing:SetAngles( gang )
				self.Wing:SetupBones()
				self.Wing:DrawModel( flags )
			end
			
		end

	end

	function ENT:RemoveWings()
		if IsValid( self.Wing ) then
			self.Wing:Remove()
		end
	end

	--copied straight from the thruster code
	function ENT:DrawJetpackFire( pos , normal , scale )
		local scroll = 1000 + UnPredictedCurTime() * -10 --1000
		
		--the trace makes sure that the light or the flame don't end up inside walls
		--although it should be cached somehow, and only do the trace every tick
		
		local tracelength = 148 * scale
		
		
		if self:GetNextFlameTrace() < UnPredictedCurTime() or not self:GetLastFlameTrace() then
			local tr = {
				start = pos,
				endpos = pos + normal * tracelength,
				mask = MASK_OPAQUE,
				filter = {
					self:GetControllingPlayer(),
					self
				},
			}
			
			self:SetLastFlameTrace( util.TraceLine( tr ) )
			self:SetNextFlameTrace( UnPredictedCurTime() +  engine.TickInterval() )
		end
		
		local traceresult = self:GetLastFlameTrace()
		
		--what
		if not traceresult then
			return
		end
		
		-- traceresult.Fraction * ( 60 * scale ) / tracelength
		
		--TODO: fix the middle segment not being proportional to the tracelength ( and Fraction )
		
		render.SetMaterial( self.MatFire )

		render.StartBeam( 3 )
			render.AddBeam( pos, 8 * scale , scroll , self.JetpackFireBlue )
			render.AddBeam( pos + normal * 60 * scale , 32 * scale , scroll + 1, self.JetpackFireWhite )
			render.AddBeam( traceresult.HitPos , 32 * scale , scroll + 3, self.JetpackFireNone )
		render.EndBeam()

		scroll = scroll * 0.5

		render.UpdateRefractTexture()
		render.SetMaterial( self.MatHeatWave )
		render.StartBeam( 3 )
			render.AddBeam( pos, 8 * scale , scroll , self.JetpackFireBlue )
			render.AddBeam( pos + normal * 32 * scale, 32 * scale , scroll + 2, color_white )
			render.AddBeam( traceresult.HitPos, 48 * scale , scroll + 5, self.JetpackFireNone )
		render.EndBeam()


		scroll = scroll * 1.3
		render.SetMaterial( self.MatHeatWave )
		render.StartBeam( 3 )
			render.AddBeam( pos , 8 * scale , scroll, self.JetpackFireBlue )
			render.AddBeam( pos + normal * 60 * scale , 16 * scale , scroll + 1 , self.JetpackFireWhite )
			render.AddBeam( traceresult.HitPos , 16 * scale , scroll + 3 , self.JetpackFireNone )
		render.EndBeam()
		
		local light = DynamicLight( self:EntIndex() )
		
		if not light then
			return
		end
		
		light.Pos = traceresult.HitPos
		light.r = self.JetpackFireRed.r
		light.g = self.JetpackFireRed.g
		light.b = self.JetpackFireRed.b
		light.Brightness = 3
		light.Dir = normal
		light.InnerAngle = -45 --light entities in a cone
		light.OuterAngle = 45 --
		light.Size = 250 * scale -- 125 when the scale is 0.25 -- 250
		light.Style = 1	--this should do the flicker for us
		light.Decay = 1000 -- 1000
		light.DieTime = UnPredictedCurTime() + 1 -- 1
	end

	function ENT:DrawJetpackSmoke( pos , normal , scale )
		
		if not self.JetpackParticleEmitter then
			local emittr = ParticleEmitter( pos )
			if not emittr then
				return
			end
			self.JetpackParticleEmitter = emittr
		end

		--to prevent the smoke from drawing inside of the player when he's looking at a mirror, draw it manually if he's the local player
		--this behaviour is disabled if he's not the one actually using the jetpack ( this also happens when the jetpack is dropped and flies off )
		
		local particlenodraw = self:IsCarriedByLocalPlayer( true )
		
		self.JetpackParticleEmitter:SetNoDraw( particlenodraw )
		
		if self:GetNextParticle() < UnPredictedCurTime() and self:GetActive() then
			local particle = self.JetpackParticleEmitter:Add( "particle/particle_noisesphere", pos )
			if particle then
				--only increase the time on a successful particle
				self:SetNextParticle( UnPredictedCurTime() + 0.01 ) -- 0.01
				particle:SetLighting( true )
				particle:SetCollide( true )
				particle:SetBounce( 0.25 )
				particle:SetVelocity( normal * self:GetJetpackSpeed() )
				particle:SetDieTime( 0.1 ) -- 0.1
				particle:SetStartAlpha( 150 )
				particle:SetEndAlpha( 0 )
				particle:SetStartSize( 16 * scale )
				particle:SetEndSize( 64 * scale )
				particle:SetRoll( math.Rand( -10 , 10  ) )
				particle:SetRollDelta( math.Rand( -0.2 , 0.2 ) )
				particle:SetColor( 255 , 255 , 255 )
			end
		end
		
		if particlenodraw then
			self.JetpackParticleEmitter:Draw()
		end
	end

end

function ENT:HandleMainActivityOverride( ply , velocity )
	if self:GetActive() then
		local vel2d = velocity:Length2D()
		local idealact = ACT_INVALID
		
		if IsValid( ply:GetActiveWeapon() ) then
			idealact = ACT_MP_SWIM	--vel2d >= 10 and ACT_MP_SWIM or ACT_MP_SWIM_IDLE
		else
			idealact = ACT_HL2MP_IDLE + 9
		end
		
		if self:GetDoGroundSlam() then
			idealact = ACT_MP_CROUCH_IDLE
		end

		return idealact , ACT_INVALID
	end
end

function ENT:HandleUpdateAnimationOverride( ply , velocity , maxseqgroundspeed )
	if self:GetActive() then
		ply:SetPlaybackRate( 0 )	--don't do the full swimming animation
		return true
	end
end

function ENT:OnRemove()

	if CLIENT then
		
		--if stopping the soundpatch doesn't work, stop the sound manually
		if self.JetpackSound then
			self.JetpackSound:Stop()
			self.JetpackSound = nil
		else
			self:StopSound( "jetpack.thruster_loop" )
		end
	
		self:RemoveWings()
		if self.JetpackParticleEmitter then
			self.JetpackParticleEmitter:Finish()
			self.JetpackParticleEmitter = nil
		end
	end
	local owner = self.Owner
	
	BaseClass.OnRemove( self )
end