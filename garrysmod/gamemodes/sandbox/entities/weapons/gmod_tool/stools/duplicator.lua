
include( "duplicator/transport.lua" )
include( "duplicator/arming.lua" )

if ( CLIENT ) then

	include( "duplicator/icon.lua" )

else

	AddCSLuaFile( "duplicator/arming.lua" )
	AddCSLuaFile( "duplicator/transport.lua" )
	AddCSLuaFile( "duplicator/icon.lua" )
	util.AddNetworkString( "CopiedDupe" )

end

TOOL.Category = "Construction"
TOOL.Name = "#tool.duplicator.name"

TOOL.Information = {
	{ name = "left" },
	{ name = "right" }
}

cleanup.Register( "duplicates" )

--
-- PASTE
--
function TOOL:LeftClick( trace )

	if ( CLIENT ) then return true end

	--
	-- Get the copied dupe. We store it on the player so it will still exist if they die and respawn.
	--
	local dupe = self:GetOwner().CurrentDupe
	if ( !dupe ) then return false end

	--
	-- We want to spawn it flush on thr ground. So get the point that we hit
	-- and take away the mins.z of the bounding box of the dupe.
	--
	local SpawnCenter = trace.HitPos
	SpawnCenter.z = SpawnCenter.z - dupe.Mins.z

	--
	-- Spawn it rotated with the player - but not pitch.
	--
	local SpawnAngle = self:GetOwner():EyeAngles()
	SpawnAngle.pitch = 0
	SpawnAngle.roll = 0

	--
	-- Spawn them all at our chosen positions
	--
	duplicator.SetLocalPos( SpawnCenter )
	duplicator.SetLocalAng( SpawnAngle )

	DisablePropCreateEffect = true

		local Ents = duplicator.Paste( self:GetOwner(), dupe.Entities, dupe.Constraints )

	DisablePropCreateEffect = nil

	duplicator.SetLocalPos( vector_origin )
	duplicator.SetLocalAng( angle_zero )

	--
	-- Create one undo for the whole creation
	--
	undo.Create( "Duplicator" )

		for k, ent in pairs( Ents ) do
			undo.AddEntity( ent )
		end

		for k, ent in pairs( Ents )	do
			self:GetOwner():AddCleanup( "duplicates", ent )
		end

		undo.SetPlayer( self:GetOwner() )

	undo.Finish()

	return true

end

--
-- Copy
--
function TOOL:RightClick( trace )

	if ( !IsValid( trace.Entity ) ) then return false end
	if ( CLIENT ) then return true end

	--
	-- Set the position to our local position (so we can paste relative to our `hold`)
	--
	duplicator.SetLocalPos( trace.HitPos )
	duplicator.SetLocalAng( Angle( 0, self:GetOwner():EyeAngles().yaw, 0 ) )

	local Dupe = duplicator.Copy( trace.Entity )

	duplicator.SetLocalPos( vector_origin )
	duplicator.SetLocalAng( angle_zero )

	if ( !Dupe ) then return false end

	--
	-- Tell the clientside that they're holding something new
	--
	net.Start( "CopiedDupe" )
		net.WriteUInt( 1, 1 )
		net.WriteVector( Dupe.Mins )
		net.WriteVector( Dupe.Maxs )
	net.Send( self:GetOwner() )

	--
	-- Store the dupe on the player
	--
	self:GetOwner().CurrentDupeArmed = false
	self:GetOwner().CurrentDupe = Dupe

	return true

end


if ( CLIENT ) then

	--
	-- Builds the context menu
	--
	function TOOL.BuildCPanel( CPanel )

		CPanel:AddControl( "Header", { Description = "#tool.duplicator.desc" } )

		CPanel:AddControl( "Button", { Text = "#tool.duplicator.showsaves", Command = "dupe_show" } )

	end

	--
	-- Received by the client to alert us that we have something copied
	-- This allows us to enable the save button in the spawn menu
	--
	net.Receive( "CopiedDupe", function( len, client )

		if ( net.ReadUInt( 1 ) == 1 ) then
			hook.Run( "DupeSaveAvailable" )
		else
			hook.Run( "DupeSaveUnavailable" )
		end

		local mins = net.ReadVector()
		local maxs = net.ReadVector()

		if ( !IsValid( LocalPlayer() ) ) then return end

		local tool = LocalPlayer():GetTool( "duplicator" )
		if ( tool ) then
			tool.CurrentDupeMins = mins
			tool.CurrentDupeMaxs = maxs
		end

	end )

	-- This is not perfect, but let the player see roughly the outline of what they are about to paste
	function TOOL:DrawHUD()

		if ( !self.CurrentDupeMins || !self.CurrentDupeMaxs || !IsValid( LocalPlayer() ) ) then return end

		local tr = LocalPlayer():GetEyeTrace()

		local pos = tr.HitPos
		pos.z = pos.z - self.CurrentDupeMins.z

		local ang = LocalPlayer():GetAngles()
		ang.p = 0
		ang.r = 0

		cam.Start3D()
		render.DrawWireframeBox( pos, ang, self.CurrentDupeMins, self.CurrentDupeMaxs )
		cam.End3D()

	end

end
