def select_hostvar(list, hostvars, var, value=True):
    return filter(lambda host: hostvars[host][var] == value, list)

class FilterModule(object):
    def filters(self):
        return {
            'selecthostvar': select_hostvar
        }
