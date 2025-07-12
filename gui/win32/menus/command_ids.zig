const min_os_id = 1;
const max_id = 60000 - 1; // Also see the comment to Contents.addCommand()

pub fn toOsId(id: usize) ?usize {
    if (id > max_id)
        return null;

    return id + min_os_id;
}

pub fn fromOsId(os_id: usize) ?usize {
    if (os_id <= min_os_id)
        return null;

    const id = os_id - min_os_id;

    if (id >= max_id)
        return null;

    return id;
}
