<?php

declare(strict_types=1);

test('/healthz returns 200 with ok payload', function () {
    $response = $this->get('/healthz');

    $response->assertOk();
    $response->assertExactJson(['status' => 'ok']);
});
