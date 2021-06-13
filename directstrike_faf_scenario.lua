version = 3 -- Lua Version. Dont touch this
ScenarioInfo = {
    name = "DirectStrike FAF",
    description = "Script and idea by Paralon, design by Lenkin. ",
    preview = '/maps/directstrike_faf.v0045/ds2.dds',
    map_version = 45,
    type = 'skirmish',
    starts = true,
    size = {512, 512},
    reclaim = {320916.6, 19.95},
    map = '/maps/directstrike_faf.v0045/directstrike_faf.scmap',
    save = '/maps/directstrike_faf.v0045/directstrike_faf_save.lua',
    script = '/maps/directstrike_faf.v0045/directstrike_faf_script.lua',
    norushradius = 40,
    Configurations = {
        ['standard'] = {
            teams = {
                {
                    name = 'FFA',
                    armies = {'ARMY_1', 'ARMY_2', 'ARMY_3', 'ARMY_4', 'ARMY_5', 'ARMY_6'}
                },
            },
            customprops = {
                ['ExtraArmies'] = STRING( 'ARMY_17 NEUTRAL_CIVILIAN SupportArmy1 SupportArmy2 SupportArmy3 SupportArmy4 SupportArmy5 SupportArmy6 ParagonArmy1 ParagonArmy2' ),
            },
        },
    },
}
