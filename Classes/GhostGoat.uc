class GhostGoat extends GGMutator;

var array<GhostGoatComponent> mGhostGoatComponents;

/**
 * See super.
 */
function ModifyPlayer(Pawn Other)
{
	local GGGoat goat;
	local GhostGoatComponent ghostComp;

	super.ModifyPlayer(Other);

	goat = GGGoat( other );
	//WorldInfo.Game.Broadcast(self, "goat=" $ goat);
	if( goat != none )
	{
		ghostComp=GhostGoatComponent(GGGameInfo( class'WorldInfo'.static.GetWorldInfo().Game ).FindMutatorComponent(class'GhostGoatComponent', goat.mCachedSlotNr));
		//WorldInfo.Game.Broadcast(self, "ghostComp=" $ ghostComp);
		if(ghostComp != none && mGhostGoatComponents.Find(ghostComp) == INDEX_NONE)
		{
			mGhostGoatComponents.AddItem(ghostComp);
			if(mGhostGoatComponents.Length == 1)
			{
				InitGhostInteraction();
			}
			RespawnPlayerCamera(PlayerController(goat.Controller));
		}
	}
}

function RespawnPlayerCamera(PlayerController goatPC)
{
	if(goatPC != None)
	{
		goatPC.PlayerCamera.Destroy();
		goatPC.PlayerCamera=none;
		// Associate Camera with PlayerController
		goatPC.PlayerCamera = Spawn( class'GGCameraPawn', goatPC );
		if( goatPC.PlayerCamera != None )
		{
			goatPC.PlayerCamera.InitializeFor( goatPC );
		}
		//WorldInfo.Game.Broadcast(self, "Camera type changed");
	}
}

function InitGhostInteraction()
{
	local GhostInteraction gi;

	gi = new class'GhostInteraction';
	gi.InitGhostInteraction(self);
	GetALocalPlayerController().Interactions.AddItem(gi);
}

function ReviveGoat(int goatId)
{
	local GhostGoatComponent ggc;

	if(goatId < 0 || goatId >= mGhostGoatComponents.Length)
	{
		WorldInfo.Game.Broadcast(self, "Error: Goat number should be between 0 and " $ (mGhostGoatComponents.Length-1));
		return;
	}

	ggc=mGhostGoatComponents[goatId];
	ggc.OnPlayerRespawn(ggc.myCont, false);
}

event Tick( float deltaTime )
{
	local GhostGoatComponent ggc;

	super.Tick( deltaTime );
	//WorldInfo.Game.Broadcast(self, "mGhostGoatComponents=" $ mGhostGoatComponents.Length);
	foreach mGhostGoatComponents(ggc)
	{
		ggc.Tick(deltaTime);
	}
}

DefaultProperties
{
	mMutatorComponentClass=class'GhostGoatComponent'
}