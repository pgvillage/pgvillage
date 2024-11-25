def filter_by_group(grouped_lists, groups):
    # Use a set to make uniue, and then convert to list again to make it json_serializable
    try:
        return list({ value for key, values in grouped_lists.items() if key in groups for value in values })
    except TypeError:
        return [ value for key, values in grouped_lists.items() if key in groups for value in values ]

class FilterModule(object):
    def filters(self):
        return {
            'bygroup': filter_by_group
        }
