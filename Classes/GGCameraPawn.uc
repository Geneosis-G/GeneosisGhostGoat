class GGCameraPawn extends GGCamera;

/**
 * Returns the best camera to use for the current state of the game
 */
protected function GameCameraBase FindBestCameraType( Actor cameraTarget )
{
	super.FindBestCameraType(cameraTarget);

	if(mCurrentCameraMode == CM_LAST_ENUM && GGPawn(cameraTarget) != none)
	{
		mCurrentCameraMode = CM_ORBIT;
	}

	return mCameraModes[ mCurrentCameraMode ];
}

DefaultProperties
{
	mCameraModesClasses(CM_ORBIT)=class'GGCameraModeOrbitalPawn'
}