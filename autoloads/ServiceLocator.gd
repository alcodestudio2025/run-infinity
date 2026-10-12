extends Node

var score_service: IScoreService = LocalScoreService.new()
var save_service: ISaveService = LocalSaveService.new()
var ad_service: IAdService = NullAdService.new()
var analytics_service: IAnalyticsService = NullAnalyticsService.new()
var achievement_service: IAchievementService = NullAchievementService.new()
